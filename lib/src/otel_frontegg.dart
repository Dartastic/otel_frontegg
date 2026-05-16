// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_frontegg_suppression.dart';

const _tracerName = 'dartastic_otel_libs_frontegg';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class FronteggResult {
  const FronteggResult({
    this.userId,
    this.vendorId,
    this.tenantId,
    this.parentTenantId,
    this.permissionsCsv,
    this.entitlementsCsv,
    this.statusCode,
  });

  final String? userId;

  /// Frontegg vendor (top-level customer of Frontegg).
  final String? vendorId;
  final String? tenantId;

  /// For nested sub-accounts, the parent tenant.
  final String? parentTenantId;
  final String? permissionsCsv;

  /// Frontegg-specific: entitlements granted on the token.
  /// Distinct from permissions which are RBAC; entitlements are
  /// feature-flag-style ("can use AI features", "premium tier").
  final String? entitlementsCsv;
  final int? statusCode;
}

class FronteggCallResult<T> {
  const FronteggCallResult({required this.value, this.result});
  final T value;
  final FronteggResult? result;
}

/// Wraps a Frontegg API call in a CLIENT span. [operation] is the
/// API route like `identity.resources.users.authenticate`,
/// `tenants.create`, `entitlements.validate`.
Future<T> tracedFrontegg<T>({
  required String operation,
  required Future<FronteggCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (fronteggInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'frontegg',
    'rpc.method': operation,
  };
  if (region != null) m['cloud.region'] = region;

  final span = _tracer().startSpan(
    'frontegg $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.userId != null) {
        extras.add(OTel.attributeString('user.id', r.result!.userId!));
      }
      if (r.result!.vendorId != null) {
        extras.add(OTel.attributeString(
          'frontegg.vendor.id',
          r.result!.vendorId!,
        ));
      }
      if (r.result!.tenantId != null) {
        extras.add(OTel.attributeString(
          'frontegg.tenant.id',
          r.result!.tenantId!,
        ));
      }
      if (r.result!.parentTenantId != null) {
        extras.add(OTel.attributeString(
          'frontegg.parent_tenant.id',
          r.result!.parentTenantId!,
        ));
      }
      if (r.result!.permissionsCsv != null) {
        extras.add(OTel.attributeString(
          'frontegg.permissions',
          r.result!.permissionsCsv!,
        ));
      }
      if (r.result!.entitlementsCsv != null) {
        extras.add(OTel.attributeString(
          'frontegg.entitlements',
          r.result!.entitlementsCsv!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Frontegg status ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
