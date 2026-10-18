// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_frontegg/otel_frontegg.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_frontegg-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('nested tenant auth records parent tenant + entitlements', () async {
    await tracedFrontegg<String>(
      operation: 'identity.resources.users.authenticate',
      region: 'eu',
      invoke: () async => const FronteggCallResult(
        value: 'ok',
        result: FronteggResult(
          userId: 'u-1',
          vendorId: 'v-acme',
          tenantId: 't-team-1',
          parentTenantId: 't-org-1',
          permissionsCsv: 'fe.secure.admin,project.read',
          entitlementsCsv: 'ai.advanced,seats.unlimited',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('frontegg identity.resources.users.authenticate')!,
    );
    expect(a['frontegg.vendor.id'], 'v-acme');
    expect(a['frontegg.tenant.id'], 't-team-1');
    expect(a['frontegg.parent_tenant.id'], 't-org-1');
    expect(a['frontegg.permissions'], 'fe.secure.admin,project.read');
    expect(a['frontegg.entitlements'], 'ai.advanced,seats.unlimited');
    expect(a['cloud.region'], 'eu');
  });

  test('403 maps to span error', () async {
    await tracedFrontegg<String>(
      operation: 'entitlements.validate',
      invoke: () async => const FronteggCallResult(
        value: 'ok',
        result: FronteggResult(statusCode: 403),
      ),
    );
    expect(
      spans.findSpanByName('frontegg entitlements.validate')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutFronteggInstrumentationAsync(() async {
      await tracedFrontegg<String>(
        operation: 'tenants.list',
        invoke: () async => const FronteggCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('frontegg '), isEmpty);
  });
}
