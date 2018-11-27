// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/src/domains/analysis/navigation_dart.dart';
import 'package:analysis_server/src/lsp/handlers/handlers.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analysis_server/src/lsp/mapping.dart';
import 'package:analysis_server/src/protocol_server.dart' show SearchResult;
import 'package:analysis_server/src/protocol_server.dart' show NavigationTarget;
import 'package:analysis_server/src/search/element_references.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/src/utilities/navigation/navigation.dart';

class ReferencesHandler
    extends MessageHandler<ReferenceParams, List<Location>> {
  ReferencesHandler(LspAnalysisServer server) : super(server);
  Method get handlesMessage => Method.textDocument_references;

  @override
  ReferenceParams convertParams(Map<String, dynamic> json) =>
      ReferenceParams.fromJson(json);

  @override
  Future<List<Location>> handle(ReferenceParams params) async {
    // TODO(dantup): Switch this to requireUnit()/getOffset() which are in a
    // "future" changeset.
    final path = pathOf(params.textDocument);
    ResolvedUnitResult result = await server.getResolvedUnit(path);
    CompilationUnit unit = result?.unit;

    if (unit == null) {
      return null;
    }

    final pos = params.position;
    final offset = result.lineInfo.getOffsetOfLine(pos.line) + pos.character;

    Element element = await server.getElementAtOffset(path, offset);
    if (element is ImportElement) {
      element = (element as ImportElement).prefix;
    }
    if (element is FieldFormalParameterElement) {
      element = (element as FieldFormalParameterElement).field;
    }
    if (element is PropertyAccessorElement) {
      element = (element as PropertyAccessorElement).variable;
    }
    if (element == null) {
      return null;
    }

    final computer = new ElementReferencesComputer(server.searchEngine);
    final results = await computer.compute(element, false);

    Location toLocation(SearchResult result) {
      final lineInfo = server.getLineInfo(result.location.file);
      return searchResultToLocation(result, lineInfo);
    }

    final referenceResults = convert(results, toLocation).toList();

    if (params.context?.includeDeclaration == true) {
      // Also include the definition for the symbol at this location.
      referenceResults.addAll(getDeclarations(unit, offset));
    }

    return referenceResults;
  }

  List<Location> getDeclarations(CompilationUnit unit, int offset) {
    final collector = new NavigationCollectorImpl();
    computeDartNavigation(server.resourceProvider, collector, unit, offset, 0);

    return convert(collector.targets, (NavigationTarget target) {
      final targetFilePath = collector.files[target.fileIndex];
      final lineInfo = server.getLineInfo(targetFilePath);
      return navigationTargetToLocation(targetFilePath, target, lineInfo);
    }).toList();
  }
}
