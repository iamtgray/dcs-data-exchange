# Next steps: gaps between reference architectures and scenarios

The four reference architectures (Level 1 Labeling, Level 1 Assured, Level 2 ABAC, Level 3 Encryption) cover a specific slice of the DCS problem space: strategic data sharing between three nations with reliable connectivity. Several scenarios need capabilities that don't exist yet.

This document maps the gaps.

## Scenario 01: Coalition Strategic Sharing

Coverage: high. The architectures were built around this scenario's actors and data flow.

Gaps:

- **Data enrichment workflow.** The scenario describes Poland encrypting data, then the UK adding their own KAS key access to the same TDF without re-encrypting the payload. The Level 3 architecture describes the AnyOf pattern conceptually but doesn't show the step-by-step process of a second nation adding their key access object to an existing TDF manifest. The SDK calls, KAS interactions, and manifest mutation needed for this aren't documented.

- **Policy conflict resolution.** Three nations with independent KAS instances will inevitably have policy disagreements. The architectures don't address what happens when UK-KAS grants access but PL-KAS denies it for the same user, or how to handle conflicting attribute definitions across national policy stores.

- **Audit aggregation.** Each nation logs independently (KAS logs, KMS CloudTrail). The scenario requires a coalition-wide audit view. There's no architecture for aggregating audit trails across three independent AWS accounts while respecting each nation's sovereignty over their logs.

## Scenario 02: Tactical Unit-to-Unit

Coverage: none. The architectures assume reliable connectivity throughout.

Gaps:

- **Offline encryption.** All three levels require online services (Lambda authorizer, Verified Permissions, KAS). There's no mechanism for encrypting data when the user has no connectivity to any key management infrastructure.

- **Offline decryption.** The Level 3 architecture requires the SDK to contact the KAS for every decryption. There's no pre-authorization token, cached key, or local policy evaluation capability.

- **Pre-distributed credentials.** The architectures use Cognito and Keycloak for real-time authentication. Tactical units need credentials that work offline for days, with acceptable staleness for certificate revocation.

- **Bandwidth efficiency.** TDF files include JSON manifests, base64-encoded wrapped keys, and ZIP structure. The overhead hasn't been measured against tactical radio bandwidth constraints.

- **Tactical-to-strategic transition.** When connectivity is restored, tactical data (encrypted with pre-distributed keys or PKI) needs to be re-wrapped as standard TDF for strategic systems. No architecture exists for this gateway function.

- **Emergency revocation.** Revoking a compromised credential offline (via radio message or manual CRL update) isn't addressed.

## Scenario 03: Legacy System Retrofit

Coverage: none. The architectures assume greenfield systems.

Gaps:

- **Automatic content classification.** The Level 1 auto-labeler does basic regex pattern matching. The scenario needs NLP-capable content analysis that can determine classification from context, not just keyword matching. Mixed-sensitivity documents (SECRET paragraph inside UNCLASSIFIED report) aren't handled.

- **Proxy/middleware integration.** The architectures are standalone systems. Retrofitting DCS onto a legacy application requires an interception layer (reverse proxy, database middleware, API gateway) that can filter responses without modifying the legacy application code.

- **Dynamic content filtering.** The architectures return whole objects (allow or deny). The scenario needs partial access: redacting specific fields, paragraphs, or sections within a single document based on the requesting user's attributes.

- **Granular labeling.** Labels in the current architectures apply to whole objects (one S3 object = one label, one DynamoDB item = one label set). The scenario needs sub-document labeling (paragraph-level, field-level).

## Scenario 04: Cross-Domain Sanitisation

Coverage: none. This is a different problem space from access control.

Gaps:

- **Intelligent redaction.** Removing sensitive content while preserving document coherence and operational value requires content understanding beyond what the current auto-labeler provides. The architectures have no redaction capability.

- **Derivative work tracking.** When a TOP SECRET document is sanitised to SECRET, the relationship between the original and the derivative needs to be tracked across classification domains. The architectures don't model cross-domain relationships.

- **Human review workflow.** Automated sanitisation requires human approval before cross-domain transfer. There's no review/approval workflow in any of the architectures.

- **Irreversibility verification.** The sanitised version must not allow reconstruction of the original. The architectures don't address this property.

- **Cross-domain solution integration.** The architectures operate within a single classification domain. Bridging between domains (TOP SECRET network to SECRET network) requires integration with existing cross-domain solutions that aren't modeled.

## Scenario 05: Mission-Based Coalition Sharing

Coverage: partial. The Level 3 architecture covers the core encryption and ABAC mechanics.

Gaps:

- **Time-based access expiry.** The architectures have no concept of time-limited access. TDF policies don't include expiry timestamps. KAS entitlements don't have start/end dates. There's no mechanism for access to automatically stop at a specific time.

- **Mission scoping.** Data in the architectures is labeled with classification, nationality, and SAP. There's no "mission" attribute that scopes data to a specific operation and its participant list.

- **Dynamic participant management without re-encryption.** Adding a new nation to a mission means they need access to all historical mission data. If that data is encrypted with TDF, the new nation's KAS key access needs to be added to every existing TDF file, or the KAS entitlement model needs to support group-based access that can be updated centrally.

- **Post-mission data lifecycle.** After a mission ends, data should become inaccessible but not deleted (for audit and lessons learned). The architectures don't model data lifecycle states (active, archived, expired, declassified).

- **Clock synchronisation.** Time-based expiry across multiple nations requires agreement on time. The architectures don't address clock skew between independent KAS instances.

## Scenario 06: Intelligence Fusion Centre

Coverage: partial. The ABAC patterns cover basic originator controls.

Gaps:

- **Attribution through fusion.** When intelligence from multiple nations is combined into a fused product, the architectures don't track which nation contributed which piece. There's no provenance model.

- **Automatic tearline generation.** Producing the same intelligence at multiple classification levels (TOP SECRET full version, SECRET sanitised version, UNCLASSIFIED public version) requires automated sanitisation. This overlaps with Scenario 04's gaps.

- **Source protection within shared products.** The scenario needs to show intelligence content while hiding the collection method. The architectures support whole-object access control but not field-level redaction within a shared product.

- **Revocation propagation to derived products.** If a nation revokes access to their contributed intelligence, all fused products containing that intelligence need to be updated or withdrawn. The architectures don't model dependencies between data objects.

- **Multi-level security in a single facility.** Analysts with different clearances working in the same environment need to see different views of the same data. The architectures return whole objects, not filtered views.

## Scenario 07: Coalition Air Operations

Coverage: minimal. The architectures are request-response, not real-time.

Gaps:

- **Real-time data propagation.** Flight plan updates need to reach all authorised consumers in seconds. The architectures use synchronous API calls (request data, get response). There's no publish-subscribe or event-driven distribution model.

- **Mixed-classification within a single entity.** A single mission has data at multiple classification levels (deconfliction data at SECRET, mission details at TOP SECRET). The architectures label whole objects at one level. There's no model for a single data entity with multiple classification facets.

- **Safety-critical override.** Airspace deconfliction data must always be available, even if the access control system fails. The architectures don't have a fail-safe mode that prioritises safety over security for specific data categories.

- **Sub-second access decisions.** The Level 2 architecture calls Verified Permissions via API, and Level 3 contacts the KAS. Both add latency that may be unacceptable for real-time air operations.

## Scenario 08: Maritime Domain Awareness

Coverage: minimal. Similar real-time gaps as air operations.

Gaps:

- **Sensor fusion with access control.** Correlating tracks from multiple nations' sensors while respecting each nation's sharing restrictions requires fusing data and applying access control simultaneously. The architectures treat access control and data processing as separate concerns.

- **Submarine compartmentalisation.** Submarine positions must be hidden even from coalition partners who can see all other military vessels. This requires negative access controls (explicitly deny specific users/nations from specific data) that go beyond the current ABAC model, which is primarily permissive.

- **Continuous data streams.** Vessel tracks update every few minutes. The architectures handle discrete objects (files, database records), not continuous position updates.

- **Exclusion zone abstraction.** Surface vessels need to know where submarines are operating (via exclusion zones) without being able to determine the submarine's actual position. This is an information abstraction problem, not just access control. The architectures don't model derived/abstracted views of protected data.

## Scenario 09: Disaster Recovery and Backup

Coverage: partial. TDF's self-protecting nature helps, but backup lifecycle isn't addressed.

Gaps:

- **Backup administrator separation.** The architectures don't model a role that can manage encrypted data (copy, move, store) without being able to decrypt it. TDF provides this property inherently, but the operational procedures and IAM policies for backup administrators aren't defined.

- **Selective restoration with access verification.** Restoring a single file from backup should verify that the requestor has access rights before restoration. The architectures don't include a restoration workflow that checks KAS entitlements before making data available.

- **Retention management.** Data has retention periods after which it should be deleted from all copies including backups. The architectures don't track retention metadata or model deletion workflows.

- **Backup media encryption.** TDF protects individual files, but backup media (tapes, disk images) needs an additional encryption layer for transport and storage. The architectures don't address this defence-in-depth requirement.

- **Long-term key availability.** If data is backed up for 10 years, the KMS keys and KAS infrastructure must remain available for that duration. The architectures don't address key lifecycle, rotation impact on existing TDF files, or KAS infrastructure longevity.

## Cross-cutting gaps

These gaps appear across multiple scenarios and aren't specific to any one:

- **Sub-document labeling and filtering.** Every scenario involving mixed-sensitivity content (03, 04, 06, 07, 08) needs labels at a finer granularity than whole objects, and the ability to return filtered views rather than whole-object allow/deny.

- **Real-time and streaming data.** Scenarios 07 and 08 need event-driven, low-latency data distribution with inline access control. The current request-response architecture doesn't fit.

- **Data relationships and provenance.** Scenarios 04, 05, and 06 need to track relationships between data objects (original to derivative, contributed intelligence to fused product, mission data to mission lifecycle). The architectures treat each data object as independent.

- **Offline and degraded operations.** Scenario 02 is the primary case, but 05 (mission operations in austere environments) and 07/08 (shipboard/airborne systems) also need some degree of offline capability.

- **Negative/deny policies.** The Cedar policies in Level 2 include a basic deny rule (revoked clearance). But scenarios 06 (NOFORN), 07 (stealth capability protection), and 08 (submarine compartmentalisation) need more sophisticated deny patterns that override permissive rules for specific data/user combinations.

- **Data lifecycle management.** Multiple scenarios need data to move through states (active, archived, expired, declassified, deleted) with access controls that change at each state. The architectures model data as static objects with fixed labels.
