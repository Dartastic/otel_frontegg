// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_frontegg/otel_frontegg.dart';

/// Traces Frontegg calls with OpenTelemetry.
///
/// `otel_frontegg` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Frontegg call in
/// [tracedFrontegg]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'frontegg-example');

  // Wraps a Frontegg API call in a CLIENT span.
  final fronteggId = await tracedFrontegg<String>(
    operation: 'tenants.create',
    region: 'us-east-1',
    invoke: () async {
      // Make the Frontegg call here, then report what it returned.
      const id = 'frontegg_8f3a2c';
      return const FronteggCallResult(
          value: id,
          result: FronteggResult(
              userId: 'user_8f3a2c',
              vendorId: 'vendor_8f3a2c',
              tenantId: 'tenant_8f3a2c',
              parentTenantId: 'parenttenant_8f3a2c',
              permissionsCsv: 'example',
              entitlementsCsv: 'example',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedFrontegg tenants.create returned $fronteggId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutFronteggInstrumentationAsync.
  await runWithoutFronteggInstrumentationAsync(
    () => tracedFrontegg<String>(
      operation: 'tenants.create',
      region: 'us-east-1',
      invoke: () async {
        const id = 'frontegg_8f3a2c';
        return const FronteggCallResult(
            value: id,
            result: FronteggResult(
                userId: 'user_8f3a2c',
                vendorId: 'vendor_8f3a2c',
                tenantId: 'tenant_8f3a2c',
                parentTenantId: 'parenttenant_8f3a2c',
                permissionsCsv: 'example',
                entitlementsCsv: 'example',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
