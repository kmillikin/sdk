import 'package:kernel/inference/extractor/constraint_extractor.dart';
import 'package:kernel/inference/solver/solver.dart';
import 'package:kernel/kernel.dart';

main(List<String> args) {
  args = ['micro.dill'];
  var program = loadProgramFromBinary(args[0]);
  var extractor = new ConstraintExtractor()..extractFromProgram(program);
  var constraints = extractor.builder.constraints;
  print('Extracted ${constraints.length} constraints');
  print(constraints
      .where((c) =>
          (c.owner as Member)?.enclosingLibrary?.importUri?.scheme == 'file')
      .join('\n'));
  var solver = new ConstraintSolver(extractor.baseHierarchy, constraints);
  solver.solve();
  print('-------');
  for (var hook in extractor.analysisCompleteHooks) {
    hook();
  }
  writeProgramToText(program, path: 'dump.txt', binding: extractor.binding);
}