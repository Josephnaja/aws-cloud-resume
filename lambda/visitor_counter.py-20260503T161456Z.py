import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    response = table.update_item(
        Key={'id': 'visitors'},
        UpdateExpression='ADD visit_count :inc',
        ExpressionAttributeValues={':inc': 1},
        ReturnValues='UPDATED_NEW'
    )
    return {
        'statusCode': 200,
        'body': json.dumps({'count': int(response['Attributes']['visit_count'])})
    }
