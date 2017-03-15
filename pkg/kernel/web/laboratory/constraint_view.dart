// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.laboratory.constraint_view;

import 'dart:html';

import 'package:kernel/ast.dart';
import 'package:kernel/inference/constraints.dart';

import 'html_buffer.dart';
import 'laboratory.dart';
import 'laboratory_ui.dart';

class ConstraintView {
  final DivElement containerElement;
  NamedNode shownObject;
  SourceRange visibleSourceRange = SourceRange.everything;

  ConstraintView(this.containerElement);

  void hide() {
    containerElement.style.visibility = 'hidden';
  }

  void setVisibleSourceRange(int start, int end) {
    visibleSourceRange = new SourceRange(start, end);
    _buildHtmlContent();
  }

  void unsetVisibleSourceRange() {
    visibleSourceRange = SourceRange.everything;
    _buildHtmlContent();
  }

  void show(NamedNode shownObject) {
    this.shownObject = shownObject;
    _buildHtmlContent();
  }

  void _buildHtmlContent() {
    if (shownObject == null) {
      hide();
      return;
    }
    var cluster = constraintSystem.getCluster(shownObject.reference);
    if (cluster == null) {
      hide();
      return;
    }
    containerElement.style.visibility = 'visible';
    containerElement.children.clear();
    var buffer = new KernelHtmlBuffer(containerElement, shownObject);
    var visitor = new ConstraintRowEmitter(buffer);
    buffer.appendPush(new TableElement());
    for (var constraint in cluster.constraints) {
      if (!visibleSourceRange.contains(constraint.fileOffset)) continue;
      buffer.appendPush(new TableRowElement());
      constraint.accept(visitor);
      buffer.pop(); // End row.
    }
    buffer.pop(); // End the table.
  }
}

class ConstraintRowEmitter extends ConstraintVisitor<Null> {
  final KernelHtmlBuffer buffer;

  ConstraintRowEmitter(this.buffer);

  TableCellElement titleCell(String name) {
    return new TableCellElement()
      ..text = name
      ..classes.add(CssClass.constraintLabel);
  }

  TableCellElement rightAlignedCell() {
    return new TableCellElement()..classes.add(CssClass.right);
  }

  TableCellElement separator() {
    return new TableCellElement()..text = ' <- ';
  }

  @override
  visitEscapeConstraint(EscapeConstraint constraint) {
    buffer
      ..appendPush(rightAlignedCell()..classes.add(CssClass.constraintEscape))
      ..appendText('escape')
      ..pop()
      ..append(separator())
      ..appendPush(new TableCellElement())
      ..appendLocation(constraint.escaping)
      ..pop()
      ..append(titleCell('Escape'));
  }

  @override
  visitSubtypeConstraint(SubtypeConstraint constraint) {
    buffer
      ..appendPush(rightAlignedCell())
      ..appendLocation(constraint.destination)
      ..pop()
      ..append(separator())
      ..appendPush(new TableCellElement())
      ..appendLocation(constraint.source)
      ..pop()
      ..append(titleCell('Subtype'));
  }

  @override
  visitTypeArgumentConstraint(TypeArgumentConstraint constraint) {
    buffer
      ..appendPush(rightAlignedCell())
      ..appendLocation(constraint.typeArgument)
      ..pop()
      ..append(separator())
      ..appendPush(new TableCellElement())
      ..appendValue(constraint.value)
      ..appendPush(new SpanElement()..classes.add(CssClass.constraintGuard))
      ..appendText(' if ')
      ..appendLocation(constraint.createdObject)
      ..appendText(' escapes')
      ..pop()
      ..pop()
      ..append(titleCell('TypeArgument'));
  }

  @override
  visitValueConstraint(ValueConstraint constraint) {
    buffer
      ..appendPush(rightAlignedCell())
      ..appendLocation(constraint.destination)
      ..pop()
      ..append(separator())
      ..appendPush(new TableCellElement())
      ..appendValue(constraint.value)
      ..pop()
      ..append(titleCell('Value'));
  }
}

class SourceRange {
  final int start, end;

  SourceRange(this.start, this.end);

  static final SourceRange everything = new SourceRange(-1, -1);

  bool get isEverything => start == -1 && end == -1;

  bool contains(int offset) {
    return isEverything || (start <= offset && offset < end);
  }
}
