// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:kernel/core_types.dart';
import 'package:kernel/dataflow/dataflow.dart';
import 'package:kernel/dataflow/storage_location.dart';
import 'package:kernel/kernel.dart';

main(List<String> args) async {
  if (args.isEmpty) args = ['flutter.dill'];
  var program = loadProgramFromBinary(args[0]);
  var coreTypes = new CoreTypes(program);
  var reporter = new DataflowReporter();
  var results =
      DataflowEngine.analyzeWholeProgram(program, diagnostic: reporter);
  var constraints = reporter.constraintSystem;
  print('Extracted ${constraints.numberOfConstraints} constraints');
  var solveTime = reporter.solvingTime.inMilliseconds;
  print('Solving took ${solveTime} ms');
  print('-------');
  writeProgramToText(program, path: 'dump.txt', binding: reporter.binding);

  var report = reporter.report;
  print('Number of changes = ${report.numberOfChangeEvents}');
  print('Number of transfers = ${report.numberOfTransferEvents}');

  Map constraintTypes = {};
  constraints.forEachConstraint((c) {
    constraintTypes[c.runtimeType] ??= 0;
    constraintTypes[c.runtimeType]++;
  });
  print(constraintTypes);

  int numTop = 0, numNullable = 0, numOther = 0;
  for (var library in program.libraries) {
    var members = [library.members, library.classes.expand((c) => c.members)]
        .expand((c) => c);
    for (var member in members) {
      var memberResults = results.getResultsForMember(member);
      var value = member is Field
          ? memberResults.value
          : memberResults.getValueOfFunctionReturn(member.function);
      if (value.baseClass == coreTypes.objectClass) {
        ++numTop;
      } else if (value.canBeNull) {
        ++numNullable;
      } else {
        ++numOther;
      }
      if (member.name.name == '==') {
        StorageLocation parameter = reporter.binding
            .getFunctionBank(member)
            .concretePositionalParameters[0]
            .source;
        if (parameter.leadsToEscape) {
          var className = member.enclosingClass.name;
          var library = '${member.enclosingLibrary.importUri}';
          print('Equals operator causing escape in class'
              ' $className from $library');
        }
      }
    }
  }
  print('Top: $numTop\nNullable: $numNullable\nOther: $numOther');
}

class FindDynamicCalls extends RecursiveVisitor {
  visitLibrary(Library node) {
    if (node.importUri.scheme == 'dart') return;
    node.visitChildren(this);
  }

  final List<String> blacklist = [
    'call',
    '==',
    'toString',
    'runtimeType',
    'hashCode'
  ];

  handleDynamicCall(Expression node, Name name) {
    if (!name.isPrivate && !blacklist.contains(name.name)) {
      print('${node.location}: $name');
    }
  }

  visitMethodInvocation(MethodInvocation node) {
    if (node.interfaceTarget == null) {
      handleDynamicCall(node, node.name);
    }
    node.visitChildren(this);
  }

  visitPropertyGet(PropertyGet node) {
    if (node.interfaceTarget == null) {
      handleDynamicCall(node, node.name);
    }
    node.visitChildren(this);
  }

  visitPropertySet(PropertySet node) {
    if (node.interfaceTarget == null) {
      handleDynamicCall(node, node.name);
    }
    node.visitChildren(this);
  }
}
