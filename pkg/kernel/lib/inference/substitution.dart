// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.strong_inference.substitution;

import '../ast.dart';
import 'augmented_type.dart';
import 'binding.dart';
import 'package:kernel/inference/key.dart';
import 'package:kernel/inference/value.dart';

abstract class Substitution {
  const Substitution();

  AType getSubstitute(TypeParameterAType parameter) {
    // Note: this is overridden in some subclasses.
    return getRawSubstitute(parameter.parameter);
  }

  AType getRawSubstitute(TypeParameter parameter);

  AType substituteType(AType type) {
    return type.substitute(this);
  }

  // TODO: Determine if this needs to be changed or just removed.
  AType substituteBound(AType type) => type.substitute(this);

  List<AType> substituteTypeList(List<AType> types) {
    return types.map((t) => t.substitute(this)).toList(growable: false);
  }

  static const Substitution empty = EmptySubstitution.instance;

  static Substitution fromSupertype(ASupertype type) {
    if (type.typeArguments.isEmpty) return empty;
    return new SupertypeSubstitution(type);
  }

  static Substitution fromInterfaceType(InterfaceAType type) {
    if (type.typeArguments.isEmpty) return empty;
    return new InterfaceSubstitution(type);
  }

  static Substitution fromPairs(
      List<TypeParameter> parameters, List<AType> types) {
    assert(parameters.length == types.length);
    if (parameters.isEmpty) return empty;
    return new PairSubstitution(parameters, types);
  }

  static Substitution either(Substitution first, Substitution second) {
    if (first == empty) return second;
    if (second == empty) return first;
    return new EitherSubstitution(first, second);
  }

  static Substitution sequence(Substitution first, Substitution second) {
    if (first == empty) return second;
    if (second == empty) return first;
    return new SequenceSubstitution(first, second);
  }

  static Substitution bottomForClass(Class class_) {
    return new BottomSubstitution(class_);
  }
}

class BottomSubstitution extends Substitution {
  final Class class_;

  BottomSubstitution(this.class_);

  @override
  AType getRawSubstitute(TypeParameter parameter) {
    if (parameter.parent == class_) {
      return new BottomAType(Value.bottom, ValueSink.nowhere);
    }
    return null;
  }
}

class EmptySubstitution extends Substitution {
  static const EmptySubstitution instance = const EmptySubstitution();

  const EmptySubstitution();

  @override
  AType substituteType(AType type) {
    return type; // Do not traverse type when there is nothing to do.
  }

  AType getRawSubstitute(TypeParameter parameter) {
    return null;
  }
}

class SupertypeSubstitution extends Substitution {
  final ASupertype type;

  SupertypeSubstitution(this.type);

  AType getSubstitute(TypeParameterAType parameterType) {
    var parameter = parameterType.parameter;
    int index = type.classNode.typeParameters.indexOf(parameter);
    if (index == -1) return null;
    AType argument = type.typeArguments[index];
    return argument.withSource(argument.source.join(parameterType.source));
  }

  AType getRawSubstitute(TypeParameter parameter) {
    int index = type.classNode.typeParameters.indexOf(parameter);
    if (index == -1) return null;
    return type.typeArguments[index];
  }
}

class InterfaceSubstitution extends Substitution {
  final InterfaceAType type;

  InterfaceSubstitution(this.type);

  AType getSubstitute(TypeParameterAType parameterType) {
    var parameter = parameterType.parameter;
    int index = type.classNode.typeParameters.indexOf(parameter);
    if (index == -1) return null;
    AType argument = type.typeArguments[index];
    return argument.withSource(argument.source.join(parameterType.source));
  }

  AType getRawSubstitute(TypeParameter parameter) {
    int index = type.classNode.typeParameters.indexOf(parameter);
    if (index == -1) return null;
    return type.typeArguments[index];
  }
}

class PairSubstitution extends Substitution {
  final List<TypeParameter> parameters;
  final List<AType> types;

  PairSubstitution(this.parameters, this.types);

  AType getRawSubstitute(TypeParameter parameter) {
    int index = parameters.indexOf(parameter);
    if (index == -1) return null;
    return types[index];
  }
}

class SequenceSubstitution extends Substitution {
  final Substitution left, right;

  SequenceSubstitution(this.left, this.right);

  AType getSubstitute(TypeParameterAType type) {
    var replacement = left.getSubstitute(type);
    if (replacement != null) {
      return right.substituteType(replacement);
    } else {
      return right.getSubstitute(type);
    }
  }

  AType getRawSubstitute(TypeParameter parameter) {
    var replacement = left.getRawSubstitute(parameter);
    if (replacement != null) {
      return right.substituteType(replacement);
    } else {
      return right.getRawSubstitute(parameter);
    }
  }
}

class EitherSubstitution extends Substitution {
  final Substitution left, right;

  EitherSubstitution(this.left, this.right);

  AType getSubstitute(TypeParameterAType type) {
    return left.getSubstitute(type) ?? right.getSubstitute(type);
  }

  AType getRawSubstitute(TypeParameter parameter) {
    return left.getRawSubstitute(parameter) ??
        right.getRawSubstitute(parameter);
  }
}

class ClosednessChecker extends Substitution {
  final Iterable<TypeParameter> typeParameters;

  ClosednessChecker(this.typeParameters);

  AType getRawSubstitute(TypeParameter parameter) {
    if (typeParameters.contains(parameter)) return null;
    throw '$parameter from ${parameter.parent} ${parameter.parent.parent} is out of scope';
  }
}
