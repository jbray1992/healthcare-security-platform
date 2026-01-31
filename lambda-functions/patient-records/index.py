import json
import boto3
import os
import base64
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize clients
dynamodb = boto3.resource('dynamodb')
kms = boto3.client('kms')
ssm = boto3.client('ssm')

# Get environment variables
TABLE_NAME = os.environ.get('TABLE_NAME')
KMS_KEY_PARAMETER = os.environ.get('KMS_KEY_PARAMETER')

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

def encrypt_field(plaintext, patient_id, record_type):
    """Encrypt a field using KMS with encryption context"""
    if not plaintext:
        return None
    
    key_id = get_kms_key_id()
    
    response = kms.encrypt(
        KeyId=key_id,
        Plaintext=plaintext.encode('utf-8'),
        EncryptionContext={
            'patient_id': patient_id,
            'record_type': record_type
        }
    )
    
    return base64.b64encode(response['CiphertextBlob']).decode('utf-8')

def decrypt_field(ciphertext_b64, patient_id, record_type):
    """Decrypt a field using KMS with encryption context"""
    if not ciphertext_b64:
        return None
    
    ciphertext = base64.b64decode(ciphertext_b64)
    
    response = kms.decrypt(
        CiphertextBlob=ciphertext,
        EncryptionContext={
            'patient_id': patient_id,
            'record_type': record_type
        }
    )
    
    return response['Plaintext'].decode('utf-8')

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
    
    # Encrypt sensitive fields
    sensitive_data = body.get('sensitive_data', {})
    encrypted_data = {}
    
    for key, value in sensitive_data.items():
        if value:
            encrypted_data[key] = encrypt_field(str(value), patient_id, record_type)
    
    # Build item
    table = dynamodb.Table(TABLE_NAME)
    item = {
        'PatientID': patient_id,
        'RecordType': record_type,
        'EncryptedData': encrypted_data,
        'NonSensitiveData': body.get('non_sensitive_data', {}),
        'CreatedAt': datetime.utcnow().isoformat(),
        'UpdatedAt': datetime.utcnow().isoformat()
    }
    
    table.put_item(Item=item)
    
    return {
        'statusCode': 201,
        'body': json.dumps({
            'message': 'Patient record created',
            'patient_id': patient_id,
            'record_type': record_type
        })
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
    
    # Decrypt sensitive fields
    encrypted_data = item.get('EncryptedData', {})
    decrypted_data = {}
    
    for key, value in encrypted_data.items():
        if value:
            try:
                decrypted_data[key] = decrypt_field(value, patient_id, record_type)
            except ClientError as e:
                decrypted_data[key] = '[DECRYPTION_FAILED]'
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'patient_id': patient_id,
            'record_type': record_type,
            'sensitive_data': decrypted_data,
            'non_sensitive_data': item.get('NonSensitiveData', {}),
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
