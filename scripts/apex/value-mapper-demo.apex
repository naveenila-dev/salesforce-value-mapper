// Execute after installing the four fictional demo records.
Map<String, Map<String, String>> mappings = MappingResolver.loadValues('ParcelDemo', 'V2');
System.assertEquals('EMP_PART', mappings.get('EmploymentType').get('Part time'));
System.assertEquals(null, mappings.get('OptionalType')?.get('source'));
System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', null).get('EmploymentType').get('Part time'));
System.assertEquals('PART_TIME', MappingResolver.loadValues('RouteDemo', 'V2').get('EmploymentType').get('Part time'));
MappingFlowAction.Input input = new MappingFlowAction.Input();
input.provider='ParcelDemo'; input.version='V2';
input.mappingType='EmploymentType'; input.sourceValue='Part time';
MappingFlowAction.Output output = MappingFlowAction.resolve(new List<MappingFlowAction.Input>{input})[0];
System.assertEquals('EMP_PART', output.value);
System.assertEquals(true, output.found);
System.debug(LoggingLevel.INFO, 'VALUE_MAPPER_DEMO_PASS');
