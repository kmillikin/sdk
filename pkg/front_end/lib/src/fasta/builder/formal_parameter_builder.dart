// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.formal_parameter_builder;

import 'package:front_end/src/fasta/parser/parser.dart' show
    FormalParameterType;

import 'builder.dart' show
    LibraryBuilder,
    MetadataBuilder,
    ModifierBuilder,
    TypeBuilder;

abstract class FormalParameterBuilder<T extends TypeBuilder>
    extends ModifierBuilder {
  final List<MetadataBuilder> metadata;

  final int modifiers;

  final T type;

  final String name;

  /// True if this parameter is on the form `this.name`.
  final bool hasThis;

  FormalParameterType kind = FormalParameterType.REQUIRED;

  FormalParameterBuilder(this.metadata, this.modifiers, this.type, this.name,
      this.hasThis, LibraryBuilder compilationUnit, int charOffset)
      : super(compilationUnit, charOffset);

  bool get isRequired => kind.isRequired;

  bool get isPositional => kind.isPositional;

  bool get isNamed => kind.isNamed;

  bool get isOptional => !isRequired;

  bool get isLocal => true;
}
