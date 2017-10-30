import boto3

ec2 = boto3.resource('ec2')
instance = ec2.create_instances(
               ImageId='ami-cd0f5cb6',
               MinCount=1,
               MaxCount=1,
               InstanceType='t2.micro')
#ec2.create_instances(ImageId='ami-cd0f5cb6', MinCount=1, MaxCount=1)
instances = ec2.instances.filter(
    Filters=[{'Name': 'instance-state-name', 'Values': ['running'], }])
for instance in instances:
    print(instance.id, instance.instance_type, instance.state)
