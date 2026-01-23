
CloudFormation do

  safe_component_name = external_parameters[:component_name].capitalize.gsub('_','').gsub('-','')

  Condition("DedicatedMasterSet", FnNot(FnEquals(Ref('DedicatedMasterCount'), 0)))
  Condition("WarmEnable", FnNot(FnEquals(Ref('WarmNodeCount'), 0)))
  Condition("ZoneAwarenessEnabled", FnNot(FnEquals(Ref(:AvailabilityZones), 1)))
  Condition("Az2", FnEquals(Ref(:AvailabilityZones), 2))
  Condition("Az3", FnEquals(Ref(:AvailabilityZones), 3))
  
  Condition("CustomEndpointEnabled", FnNot(FnEquals(Ref(:CustomEndpoint), '')))

  sg_tags = []
  sg_tags << { Key: 'Environment', Value: Ref(:EnvironmentName)}
  sg_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType)}
  sg_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")}

  extra_tags = external_parameters.fetch(extra_tags, {})
  extra_tags.each { |key,value| sg_tags << { Key: "#{key}", Value: FnSub(value) } }
  
  ip_blocks = external_parameters.fetch(:ip_blocks, {})
  security_group_rules = external_parameters.fetch(:security_group_rules, [])

  EC2_SecurityGroup("SecurityGroupES") do
    GroupDescription FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")
    VpcId Ref('VPCId')
    if security_group_rules.any?
      SecurityGroupIngress generate_security_group_rules(security_group_rules,ip_blocks)
    end
    Tags sg_tags
  end

  security_groups = external_parameters.fetch(:security_groups, {})
  security_groups.each do |name, sg|
    sg['ports'].each do |port|
      EC2_SecurityGroupIngress("#{name}SGRule#{port['from']}") do
        Description FnSub("Allows #{port['from']} from #{name}")
        IpProtocol 'tcp'
        FromPort port['from']
        ToPort port.key?('to') ? port['to'] : port['from']
        GroupId FnGetAtt("SecurityGroupES",'GroupId')
        SourceSecurityGroupId sg.key?('stack_param') ? Ref(sg['stack_param']) : Ref(name)
      end
    end if sg.key?('ports')
  end



  advanced_options = external_parameters.fetch(:advanced_options, {})
  ebs_options = external_parameters.fetch(:ebs_options, {})
  aiml_options = external_parameters.fetch(:aiml_options, {})
  domain_endpoint_options = external_parameters.fetch(:domain_endpoint_options, {})
  enforce_https = domain_endpoint_options.has_key?('EnforceHTTPS') ? domain_endpoint_options['EnforceHTTPS'] : 'false'
  tls_policy = domain_endpoint_options.has_key?('TLSSecurityPolicy') ? domain_endpoint_options['TLSSecurityPolicy'] : Ref('AWS::NoValue')
  enable_version_upgrade = external_parameters.fetch(:enable_version_upgrade, nil)

  subnets = FnIf('Az2',
                [
                  FnSelect(0, FnSplit(',', Ref('Subnets'))), 
                  FnSelect(1, FnSplit(',', Ref('Subnets')))
                ],
                FnIf('Az3',
                  [
                    FnSelect(0, FnSplit(',', Ref('Subnets'))), 
                    FnSelect(1, FnSplit(',', Ref('Subnets'))), 
                    FnSelect(2, FnSplit(',', Ref('Subnets')))
                  ],
                  [
                    FnSelect(0, FnSplit(',', Ref('Subnets')))
                  ]
                )
              )

    
  openSearchService_Domain('OpenSearchVPCCluster') do
    DomainName Ref('OSDomainName')
    AdvancedOptions advanced_options unless advanced_options.empty?
    Property(:DomainEndpointOptions, {
         EnforceHTTPS: enforce_https,
         TLSSecurityPolicy: tls_policy,
         CustomEndpointEnabled: FnIf('CustomEndpointEnabled', 'true','false'),
         CustomEndpoint: FnIf('CustomEndpointEnabled', Ref('CustomEndpoint'), Ref('AWS::NoValue')),
         CustomEndpointCertificateArn: FnIf('CustomEndpointEnabled', Ref('CustomEndpointCertificateArn'), Ref('AWS::NoValue')),
    })
    AIMLOptions aiml_option unless aiml_option.empty?
    EBSOptions ebs_options unless ebs_options.empty?
    ClusterConfig({
      DedicatedMasterEnabled: FnIf('DedicatedMasterSet', true, false),
      DedicatedMasterCount: FnIf('DedicatedMasterSet', Ref('DedicatedMasterCount'), Ref('AWS::NoValue')),
      DedicatedMasterType: FnIf('DedicatedMasterSet', Ref('DedicatedMasterType'), Ref('AWS::NoValue')),
      InstanceCount: Ref('InstanceCount'),
      InstanceType: Ref('InstanceType'),
      WarmEnabled: FnIf('WarmEnable', true, false),
      WarmCount: FnIf('WarmEnable', Ref('WarmNodeCount'), Ref('AWS::NoValue')),
      WarmType: FnIf('WarmEnable', Ref(:WarmNodeType), Ref('AWS::NoValue')),
      ZoneAwarenessEnabled: FnIf('ZoneAwarenessEnabled', 'true','false'),
      ZoneAwarenessConfig: FnIf('ZoneAwarenessEnabled', 
        {
          AvailabilityZoneCount: Ref(:AvailabilityZones)
        },
        Ref('AWS::NoValue')
      )
    })
    EngineVersion Ref('EngineVersion')
    EncryptionAtRestOptions({
      Enabled: Ref('EncryptionAtRest')
    })
    SnapshotOptions({
      AutomatedSnapshotStartHour: Ref('AutomatedSnapshotStartHour')
    })
    VPCOptions({
      SubnetIds: subnets,
      SecurityGroupIds: [Ref('SecurityGroupES')]
    })
    Tags sg_tags
    AccessPolicies(
      {
        Version: "2012-10-17",
        Statement: [{
          Effect: "Allow",
          Principal: {
            AWS: "*"
          },
          Action: "es:*",
          Resource: FnSub("arn:aws:es:${AWS::Region}:${AWS::AccountId}:domain/${OSDomainName}/*")
        }]
      }
    )
    UpdatePolicy(:EnableVersionUpgrade, enable_version_upgrade) unless enable_version_upgrade.nil?
  end

  Output("ESClusterEndpoint") do
    Value(FnGetAtt('OpenSearchVPCCluster', 'DomainEndpoint'))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-ESClusterEndpoint")
  end

  Output("SecurityGroupES") do
    Value(Ref('SecurityGroupES'))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-SecurityGroup")
  end

end
