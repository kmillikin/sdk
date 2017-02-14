// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/codegen/tools.dart';

import 'api.dart';
import 'codegen_dart.dart';
import 'from_html.dart';

final GeneratedFile target =
    new GeneratedFile('lib/protocol/protocol_constants.dart', (String pkgPath) {
  CodegenVisitor visitor = new CodegenVisitor(readApi(pkgPath));
  return visitor.collectCode(visitor.visitApi);
});

/**
 * A visitor that produces Dart code defining constants associated with the API.
 */
class CodegenVisitor extends DartCodegenVisitor with CodeGenerator {
  CodegenVisitor(Api api) : super(api) {
    codeGeneratorSettings.commentLineLength = 79;
    codeGeneratorSettings.languageName = 'dart';
  }

  /**
   * Generate all of the constants associates with the [api].
   */
  void generateConstants() {
    _ConstantVisitor visitor = new _ConstantVisitor(api);
    visitor.visitApi();
    List<_Constant> constants = visitor.constants;
    constants.sort((first, second) => first.name.compareTo(second.name));
    for (_Constant constant in constants) {
      generateContant(constant);
    }
  }

  /**
   * Generate the given [constant].
   */
  void generateContant(_Constant constant) {
    write('const String ');
    write(constant.name);
    write(' = ');
    write(constant.value);
    writeln(';');
  }

  @override
  visitApi() {
    outputHeader(year: '2017');
    writeln();
    generateConstants();
  }
}

/**
 * A representation of a constant that is to be generated.
 */
class _Constant {
  /**
   * The name of the constant.
   */
  final String name;

  /**
   * The value of the constant.
   */
  final String value;

  /**
   * Initialize a newly created constant.
   */
  _Constant(this.name, this.value);
}

/**
 * A visitor that visits an API to compute a list of constants to be generated.
 */
class _ConstantVisitor extends HierarchicalApiVisitor {
  /**
   * The list of constants to be generated.
   */
  List<_Constant> constants = <_Constant>[];

  /**
   * Initialize a newly created visitor to visit the given [api].
   */
  _ConstantVisitor(Api api) : super(api);

  @override
  void visitNotification(Notification notification) {
    String domainName = notification.domainName;
    String event = notification.event;

    String constantName = _generateName(domainName, 'notification', event);
    constants.add(new _Constant(constantName, "'$domainName.$event'"));
    _addFieldConstants(constantName, notification.params);
  }

  @override
  void visitRequest(Request request) {
    String domainName = request.domainName;
    String method = request.method;

    String requestConstantName = _generateName(domainName, 'request', method);
    constants.add(new _Constant(requestConstantName, "'$domainName.$method'"));
    _addFieldConstants(requestConstantName, request.params);

    String responseConstantName = _generateName(domainName, 'response', method);
    _addFieldConstants(responseConstantName, request.result);
  }

  /**
   * Generate a constant for each of the fields in the given [type], where the
   * name of each constant will be composed from the [parentName] and the name
   * of the field.
   */
  void _addFieldConstants(String parentName, TypeObject type) {
    if (type == null) {
      return;
    }
    type.fields.forEach((TypeObjectField field) {
      String name = field.name;
      String fieldConstantName = parentName + '_' + name.toUpperCase();
      constants.add(new _Constant(fieldConstantName, "'$name'"));
    });
  }

  /**
   * Generate a name from the [domainName], [kind] and [name] components.
   */
  String _generateName(String domainName, String kind, String name) {
    List<String> components = <String>[];
    components.addAll(_split(domainName));
    components.add(kind);
    components.addAll(_split(name));
    return components
        .map((String component) => component.toUpperCase())
        .join('_');
  }

  /**
   * Return the components of the given [string] that are indicated by an upper
   * case letter.
   */
  Iterable<String> _split(String first) {
    RegExp regExp = new RegExp('[A-Z]');
    List<String> components = <String>[];
    int start = 1;
    int index = first.indexOf(regExp, start);
    while (index >= 0) {
      components.add(first.substring(start - 1, index));
      start = index + 1;
      index = first.indexOf(regExp, start);
    }
    components.add(first.substring(start - 1));
    return components;
  }
}
