CfhighlanderTemplate do

  DependsOn 'lib-ec2@0.1.0'

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', allowedValues: ['development','production'], isGlobal: true
    ComponentParam 'AvailabilityZones', 1, isGlobal: true, allowedValues: [1,2,3]
    
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'Subnets'
    security_groups.each do |name, sg|
      ComponentParam name
    end if defined? security_groups

    ComponentParam 'OSDomainName'
    ComponentParam 'EngineVersion'
    ComponentParam 'InstanceCount', 1
    ComponentParam 'InstanceType', 't2.micro.elasticsearch'
    ComponentParam 'EncryptionAtRest', 'true', allowedValues: ['true','false']
    ComponentParam 'AutomatedSnapshotStartHour', '0'
    ComponentParam 'CustomEndpoint', ''
    ComponentParam 'CustomEndpointCertificateArn', ''
    ComponentParam 'DedicatedMasterCount', 0
    ComponentParam 'DedicatedMasterType'

    ComponentParam 'WarmNodeCount', 0
    ComponentParam 'WarmNodeType', 'ultrawarm1.medium.elasticsearch'

  end

end