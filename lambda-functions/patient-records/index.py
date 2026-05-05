import json
import boto3
import os
import base64
from datetime import datetime
from botocore.exceptions import ClientError
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Initialize clients
dynamodb = boto3.resource('dynamodb')
kms = boto3.client('kms')
ssm = boto3.client('ssm')
bedrock_runtime = boto3.client('bedrock-runtime')

# Get environment variables
TABLE_NAME = os.environ.get('TABLE_NAME')
KMS_KEY_PARAMETER = os.environ.get('KMS_KEY_PARAMETER')
GUARDRAIL_ID = os.environ.get('GUARDRAIL_ID')
GUARDRAIL_VERSION = os.environ.get('GUARDRAIL_VERSION')

# Cache for KMS key ID
_kms_key_id = None

def get_kms_key_id():
    """Retrieve KMS key ID from Parameter Store (cached)"""
    global _kms_key_id
    if _kms_key_id is None:
        response = ssm.get_parameter(
            Name=KMS_KEY_PARAMETER,
            WithDecryption=True
        )
        _kms_key_id = response['Parameter']['Value']
    return _kms_key_id

def apply_guardrail(text):
    """Apply Bedrock Guardrail to detect and filter PII"""
    if not text or not GUARDRAIL_ID:
        return text, False

    try:
        response = bedrock_runtime.apply_guardrail(
            guardrailIdentifier=GUARDRAIL_ID,
            guardrailVersion=GUARDRAIL_VERSION,
            source='INPUT',
            content=[{'text': {'text': text}}]
        )

        action = response.get('action', 'NONE')

        if action == 'GUARDRAIL_INTERVENED':
            outputs = response.get('outputs', [])
            if outputs:
                filtered_text = outputs[0].get('text', text)
                return filtered_text, True
            return text, True

        return text, False

    except ClientError as e:
        print(f"Guardrail error: {e}")
        return text, False

def encrypt_field(plaintext, patient_id, record_type):
    """
    Envelope encryption:
      1. Ask KMS for a fresh 256-bit data key (returns plaintext + encrypted form).
      2. Encrypt the field locally with AES-256-GCM using the plaintext data key.
      3. Discard the plaintext data key from memory.
      4. Store the encrypted data key alongside the ciphertext.

    Encryption context binds the data key to (patient_id, record_type) so the
    encrypted data key cannot be decrypted under a different context. This
    preserves the same authorization guarantee the previous direct-KMS design had.
    """
    if not plaintext:
        return None

    key_id = get_kms_key_id()

    # 1. Generate data key
    dk_response = kms.generate_data_key(
        KeyId=key_id,
        KeySpec='AES_256',
        EncryptionContext={
            'patient_id': patient_id,
            'record_type': record_type
        }
    )
    plaintext_key = dk_response['Plaintext']
    encrypted_key = dk_response['CiphertextBlob']

    # 2. Local encrypt with AES-GCM
    aesgcm = AESGCM(plaintext_key)
    nonce = os.urandom(12)  # 96-bit nonce, NIST recommendation for GCM
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode('utf-8'), None)

    # 3. Best-effort wipe of the plaintext data key reference
    del plaintext_key

    # 4. Package: encrypted data key + (nonce || ciphertext || tag)
    envelope = {
        'key': base64.b64encode(encrypted_key).decode('utf-8'),
        'data': base64.b64encode(nonce + ciphertext).decode('utf-8')
    }
    return json.dumps(envelope)

def decrypt_field(envelope_json, patient_id, record_type):
    """
    Reverse of encrypt_field:
      1. Parse envelope.
      2. Ask KMS to decrypt the data key (with same encryption context).
      3. Local AES-GCM decrypt of the field ciphertext.
    """
    if not envelope_json:
        return None

    envelope = json.loads(envelope_json)
    encrypted_key = base64.b64decode(envelope['key'])
    blob = base64.b64decode(envelope['data'])

    nonce = blob[:12]
    ciphertext = blob[12:]

    dk_response = kms.decrypt(
        CiphertextBlob=encrypted_key,
        EncryptionContext={
            'patient_id': patient_id,
            'record_type': record_type
        }
    )
    plaintext_key = dk_response['Plaintext']

    aesgcm = AESGCM(plaintext_key)
    plaintext = aesgcm.decrypt(nonce, ciphertext, None)

    del plaintext_key
    return plaintext.decode('utf-8')

def create_patient(event):
    """Create a new patient record"""
    body = json.loads(event.get('body', '{}'))

    patient_id = body.get('patient_id')
    record_type = body.get('record_type', 'DEMOGRAPHICS')

    if not patient_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'patient_id is required'})
        }

    sensitive_data = body.get('sensitive_data', {})
    pii_detected = False

    if 'clinical_notes' in sensitive_data:
        filtered_notes, was_filtered = apply_guardrail(sensitive_data['clinical_notes'])
        sensitive_data['clinical_notes'] = filtered_notes
        pii_detected = was_filtered

    encrypted_data = {}
    for key, value in sensitive_data.items():
        if value:
            encrypted_data[key] = encrypt_field(str(value), patient_id, record_type)

    table = dynamodb.Table(TABLE_NAME)
    item = {
        'PatientID': patient_id,
        'RecordType': record_type,
        'EncryptedData': encrypted_data,
        'NonSensitiveData': body.get('non_sensitive_data', {}),
        'PIIFiltered': pii_detected,
        'CreatedAt': datetime.utcnow().isoformat(),
        'UpdatedAt': datetime.utcnow().isoformat()
    }

    table.put_item(Item=item)

    response_body = {
        'message': 'Patient record created',
        'patient_id': patient_id,
        'record_type': record_type
    }

    if pii_detected:
        response_body['warning'] = 'PII was detected and filtered from clinical notes'

    return {
        'statusCode': 201,
        'body': json.dumps(response_body)
    }

def get_patient(event):
    """Retrieve and decrypt a patient record"""
    params = event.get('pathParameters', {}) or {}
    query = event.get('queryStringParameters', {}) or {}

    patient_id = params.get('patient_id')
    record_type = query.get('record_type', 'DEMOGRAPHICS')

    if not patient_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'patient_id is required'})
        }

    table = dynamodb.Table(TABLE_NAME)

    try:
        response = table.get_item(
            Key={
                'PatientID': patient_id,
                'RecordType': record_type
            }
        )
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    item = response.get('Item')

    if not item:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Patient record not found'})
        }

    encrypted_data = item.get('EncryptedData', {})
    decrypted_data = {}

    for key, value in encrypted_data.items():
        if value:
            try:
                decrypted_data[key] = decrypt_field(value, patient_id, record_type)
            except (ClientError, ValueError, KeyError) as e:
                decrypted_data[key] = '[DECRYPTION_FAILED]'

    return {
        'statusCode': 200,
        'body': json.dumps({
            'patient_id': patient_id,
            'record_type': record_type,
            'sensitive_data': decrypted_data,
            'non_sensitive_data': item.get('NonSensitiveData', {}),
            'pii_filtered': item.get('PIIFiltered', False),
            'created_at': item.get('CreatedAt'),
            'updated_at': item.get('UpdatedAt')
        })
    }

def delete_patient(event):
    """Delete a patient record"""
    params = event.get('pathParameters', {}) or {}
    query = event.get('queryStringParameters', {}) or {}

    patient_id = params.get('patient_id')
    record_type = query.get('record_type', 'DEMOGRAPHICS')

    if not patient_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'patient_id is required'})
        }

    table = dynamodb.Table(TABLE_NAME)

    try:
        table.delete_item(
            Key={
                'PatientID': patient_id,
                'RecordType': record_type
            }
        )
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Patient record deleted',
            'patient_id': patient_id,
            'record_type': record_type
        })
    }

def lambda_handler(event, context):
    """Main Lambda handler"""
    http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method'))

    if http_method == 'POST':
        return create_patient(event)
    elif http_method == 'GET':
        return get_patient(event)
    elif http_method == 'DELETE':
        return delete_patient(event)
    else:
        return {
            'statusCode': 405,
            'body': json.dumps({'error': 'Method not allowed'})
        }
