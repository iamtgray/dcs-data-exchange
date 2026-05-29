# DP4: Data must flow across classification boundaries through validated cross-domain solutions

**Addresses:** CG2 — Eliminate Information Boundaries as a Constraint on Operational Tempo; CG1 — Achieve Decision Superiority Through Faster Information Delivery; CC1 — The "Digital Air-Gap" (Cross-Domain Latency)

## Why this matters

Risk boundaries are the single biggest barrier to machine-speed decision making. A risk boundary exists wherever data crosses a trust boundary that requires validation — classification boundaries are the most obvious example (intelligence collected at TOP SECRET must inform targeting decisions at SECRET; tactical observations at RESTRICTED must feed operational planning at SECRET), but they are not the only one. Data flowing between international partners at the same classification level — such as east-to-west transfers between allied nations — crosses a sovereignty and integrity boundary that demands equivalent rigour. Without automated, validated cross-domain solutions at every risk boundary, data movement depends on manual review processes that introduce hours or days of latency. Without a CDS at this boundary, a breach in one nation or organisation's network could propagate unchecked into another's.

## Implementation guidance

### Treat risk boundaries with the same rigour as classification boundaries

The formal basis for treating risk boundaries as seriously as classification boundaries is the [Biba integrity model](https://en.wikipedia.org/wiki/Biba_Model). Biba does not distinguish between "lower classification" and "lower assurance" — it only asks whether the source environment's integrity guarantees are weaker than the destination's. Where they are, sanitisation is required before ingestion regardless of whether the data carries the same classification markings. This means a boundary between two SECRET networks with different assurance levels demands the same CDS rigour as a boundary between SECRET and RESTRICTED.

At such a boundary, both integrity and confidentiality are concerns:

- **Integrity (inbound):** Preventing contamination of a higher-assurance environment by data from a lower-assurance one. Apply import treatments — content disarm and reconstruction, format verification, integrity validation — to ensure untrusted data cannot corrupt the destination.

- **Confidentiality (outbound):** Preventing data from leaking to an environment where originator control, releasability, or operational sensitivity cannot be assured. A nation's SECRET network contains data that is SECRET *to that nation*; another nation's SECRET network at the same classification level is not automatically entitled to that data. Apply confidentiality treatments — label checking, dirty word search, releasability enforcement — on the outbound path.

Apply both sets of treatments at risk boundaries just as you would at a classification boundary. The integrity argument comes from Biba; the confidentiality argument is driven by originator control and sovereignty — data owners retain the right to control onward sharing regardless of the recipient's classification level.

### Select the CDS type based on data flow direction, assurance requirement, and deployment environment

Cross-domain solutions are not a single technology — they are a family of architectures, each with distinct security arguments and operational trade-offs. The choice between them is risk-based: match the CDS assurance level to the risk boundary it protects, the data flow pattern required, and the deployment constraints of the environment.

#### Hardware data diodes

Hardware data diodes enforce one-way data flow through physical design — typically an optical transmitter with no receiver on the sending side, making reverse data flow physically impossible. The security argument is rooted in physics rather than software correctness, which makes them the highest-assurance CDS type available for enforcing directionality.

**Critical distinction:** A diode protects the *source* from the *destination* — it guarantees nothing can reach back to attack the source system. It does **not** inherently protect the destination from the source. If an attacker compromises the source system feeding a diode, the diode will pass whatever the attacker injects because it enforces direction, not content. Destination protection requires additional controls.

In practice, diode deployments exist on a spectrum of inspection depth:

- **Pure diode (no inspection):** Raw one-way link. Whatever enters one side exits the other. Used for continuous streaming feeds (radar tracks, SCADA telemetry, video) where the source is physically secured, the data format is highly constrained, and the primary threat model is attack *toward* the source rather than *from* it. Examples include nuclear plant monitoring (ICS telemetry streamed to corporate historians), military radar feeds (Link 16/ASTERIX track data to fusion centres), and CCTV export from secure facilities.

- **Diode with receiving-side validation:** The diode itself is still a raw one-way link, but a proxy on the receiving side performs schema validation, bounds checking, and anomaly detection. Messages that don't conform to the expected format are dropped. This catches obvious injection without adding latency to the diode path itself — validation happens after transit, not during it.

- **Diode with cryptographic integrity:** The source signs each message or batch. The receiving side verifies the signature before accepting data. This proves provenance without inspecting content — if an attacker compromises the source but doesn't obtain the signing key, they cannot inject valid messages. Military messaging protocols (e.g., Link 16) use this approach.

- **Diode with full treatment pipeline:** Sending-side or receiving-side proxies perform content inspection (format verification, CDR, label checking). At this point the deployment functionally resembles a one-way guard — the distinction from a bidirectional guard is that the one-way property is still physically enforced, but the inspection depth approaches guard-level rigour.

Most real-world diode deployments sit somewhere in the middle of this spectrum. The choice of inspection depth is driven by the latency budget, the predictability of the data format, and whether the threat model prioritises protecting the source (diode's inherent property) or protecting the destination (requires additional validation).

Hardware diodes are appropriate where:

- The risk boundary demands the strongest possible assurance argument for directionality (e.g., between TOP SECRET and SECRET, or between a national network and a coalition network)
- Physical infrastructure is available to host the hardware
- The accreditation authority requires a hardware-enforced security argument

Hardware diodes are **not** appropriate where:

- The deployment environment is cloud-only (custom hardware cannot run in public cloud)
- Size, weight, and power constraints preclude rack-mounted equipment
- The risk boundary does not warrant the cost and complexity of hardware enforcement

Note that bidirectional data flow does not preclude hardware diodes. Hardware appliances exist that package two independent one-way channels (one in each direction) into a single chassis, providing bidirectional data exchange while maintaining the physics-based one-way assurance argument for each direction independently. These are discussed further under "Diode messaging" below.

**Key point:** Hardware diodes are the highest-assurance *option* for enforcing directionality, not a blanket default for all cross-domain boundaries. The assurance level of the CDS should be proportionate to the risk at the boundary. A RESTRICTED-to-RESTRICTED sovereignty boundary between allied nations may be adequately served by a software CDS with appropriate accreditation, while a TOP SECRET-to-SECRET boundary handling intelligence sources and methods may demand hardware enforcement.

#### Software data diodes

Software data diodes enforce one-way data flow through software controls rather than physical hardware. They provide the same logical guarantee — data flows in one direction only — but the security argument rests on software correctness and configuration rather than physics.

Software diodes are viable and often preferred where:

- The deployment environment is cloud-based (hardware cannot be installed in public cloud infrastructure)
- The risk boundary is between environments at the same or adjacent classification levels
- Operational tempo demands rapid deployment and scaling
- The accreditation framework accepts software-enforced one-way flow

Cloud providers offer software diode capabilities that enforce one-way data transfer between isolated environments. These are appropriate for cloud-to-cloud domain separation where the classification boundary exists between logically separated cloud accounts or regions rather than between physically isolated networks.

**Trade-off:** Software diodes have a weaker assurance argument than hardware diodes (software can have bugs; physics cannot), but they are deployable in environments where hardware is impossible and can be scaled, updated, and managed through standard cloud operations.

#### Diode messaging (logical bidirectional flow via paired one-way channels)

Where bidirectional data flow is required but the security argument must remain rooted in one-way enforcement, diode messaging uses two independent one-way channels — one in each direction — to create a logical bidirectional flow. Each channel is independently enforced (hardware or software) with its own treatment pipeline.

This is fundamentally different from a bidirectional guard:

- A **bidirectional guard** is a single system aware of both inbound and outbound flows, applying content inspection in both directions
- **Diode messaging** is two separate, independent one-way systems that have no awareness of each other — the export diode cannot influence the import diode and vice versa

The security advantage is that no single system is aware of both the inbound and outbound flows. A compromise of the export path cannot affect the import path because they are physically or logically separate systems. This eliminates a class of attacks where an adversary exploits bidirectional awareness to create covert channels or exfiltrate data by manipulating the return path.

Diode messaging is appropriate where:

- Bidirectional data exchange is operationally required
- The assurance requirement is higher than a single bidirectional guard can provide
- The data flows in each direction have different security concerns (confidentiality on export, integrity on import)
- The accreditation authority requires independent assurance arguments for each direction

#### Bidirectional guards

Bidirectional guards handle data flow in both directions through content inspection. A guard terminates the inbound network connection, extracts the data payload, runs it through a pipeline of security treatments, and reconstructs a completely new connection on the other side — the source and destination never have a direct network path. Guards apply different treatment pipelines per direction: the export path (high-to-low) focuses on preventing classified disclosure; the import path (low-to-high) focuses on preventing malware and integrity attacks.

Guards operate as a protocol break: they terminate the source protocol, extract the data payload into a normalised internal representation, apply the treatment pipeline, and then reconstruct the data in the destination protocol. Source and destination never share a network session, TCP connection, or application-layer protocol state. This protocol break is the fundamental security mechanism — it ensures that protocol-level attacks, covert channels embedded in protocol headers, and session-hijacking attacks cannot traverse the boundary.

The protocol break also enables format transformation. Data entering the guard in one format (e.g., a proprietary military messaging format) can exit in another (e.g., a NATO STANAG-compliant format) because the guard works on the extracted payload, not the transport wrapper.

#### Access solutions (remote browsing / pixel streaming)

Access solutions allow users to view and interact with data in a different security domain without that data leaving the domain. A thin client renders the classified desktop as a pixel stream — no files, clipboard data, or application protocols cross the boundary. The data stays on the classified system; only rendered video reaches the user's workstation.

Access solutions are appropriate where:

- Users need to *view* data in another domain but the data must not *move* to their domain
- The operational requirement is interactive access (browsing, querying) rather than data transfer
- The risk of data exfiltration through file transfer is unacceptable
- Users need access to multiple classification domains from a single workstation

### Implement identity and trust across CDS boundaries

Before any data queries or transfers happen across a CDS boundary (especially when querying from the high-side to the low-side of trust), the identity gap must be bridged without leaking high-side credentials to the low side.

#### Stage 1: Limited-attribute token issuance

The high-side Identity Provider (IdP) issues a limited-attribute JWT containing only the minimum claims needed for the low-side to make access decisions:

- User ID (opaque identifier)
- Organisation ID
- Clearance level (e.g., SECRET)

The token **must not** contain high-side-specific roles, email addresses, group memberships, or any attribute that could reveal the structure or operations of the high-side environment if the token were compromised on the low side.

#### Stage 2: Trust establishment via JWKS export

Export the public key (JWKS) from the high-side IdP and import it into the low-side identity system (e.g., Keycloak, Cognito, or equivalent). This allows the low side to verify the token's signature without needing real-time communication back to the high-side IdP. The trust relationship is established through pre-shared cryptographic material, not through network connectivity.

This is critical because:

- The CDS may be a one-way diode (no return path for token validation)
- Real-time IdP communication across the boundary would create a dependency that degrades availability
- The high-side IdP should not be reachable from the low side under any circumstances

#### Stage 3: Attribute screening before token exchange

Before generating a new token for authenticated requests through the CDS, verify and screen the attributes in the source token. Read-on codes, compartment memberships, and specific role assignments can be classified in their own right. The purpose of token exchange at the CDS boundary is to:

- Strip attributes that are classified above the destination domain's level
- Map source-domain attributes to destination-domain equivalents
- Ensure no classified attribute values leak across the boundary
- Generate a new token with only the attributes appropriate for the destination domain

This protects against leaking classified attributes across boundaries — a user's membership in a specific compartment may itself be classified, even if the data they're accessing is not.

### Implement catalog synchronisation and data access patterns

#### Catalog synchronisation (low-to-high)

Synchronise the data catalog from the low-classification domain to the high-classification domain so that high-side users can discover and query low-side data products without crossing the boundary for every catalog lookup. This means:

- Catalog metadata flows upward (low → high) through the CDS
- High-side users browse the catalog locally with no cross-domain latency
- Only actual data requests traverse the CDS
- Catalog updates propagate on a schedule or via event-driven sync

For high-to-low catalog visibility (allowing low-side users to know what's available on the high side without seeing classified content), publish a sanitised catalog — titles, abstracts, and access request procedures without revealing classified details.

#### Data access via mesh proxy

Rather than allowing direct queries from one domain to data sources in another (which would require bidirectional application-layer connectivity across the CDS), implement a mesh proxy pattern:

1. The requesting domain submits a query to the CDS boundary
2. A proxy on the data-provider side of the CDS receives the query
3. The proxy makes the call directly to the data provider's API/endpoint
4. The proxy receives the results
5. The results are pushed back through the CDS (with appropriate treatment)
6. The requesting domain receives the response

This pattern:

- Keeps the CDS as a protocol break (no end-to-end application sessions)
- Allows the proxy to enforce additional access controls on the provider side
- Enables the CDS treatment pipeline to inspect both the query and the response
- Prevents the requesting domain from having direct network access to provider-side infrastructure
- Works with both diode messaging (two one-way channels) and bidirectional guards

### Implement content-based filtering and transformation within the CDS treatment pipeline

CDS must inspect data content, not just metadata, to enforce security policy. The treatment pipeline applies multiple sequential checks — each addressing a different threat vector, each preparing data for the next stage. Assurance is gained through the pipeline, not at any single point.

Key treatments include:

- **Format verification**: Confirming file types match their declaration (preventing disguised executables)
- **Content disarm and reconstruction (CDR)**: Stripping and rebuilding files to a known-good standard, effective against zero-day exploits embedded in document features
- **Security label checking**: Enforcing flow policy based on STANAG 4774/4778 classification labels
- **Dirty word searching**: Detecting classified terms in outbound content
- **Metadata stripping**: Removing hidden information that could leak (EXIF data, revision history, embedded comments)
- **Schema validation**: Checking structured data conforms to expected schemas
- **Anti-covert-channel normalisation**: Removing encoding variants that could carry hidden signals (whitespace patterns, Unicode alternatives, timing variations)

The specific pipeline is configured per data type and per flow direction — an inbound Office document needs CDR and active content removal; an outbound intelligence report needs dirty word search, label checking, and potentially human review; a streaming sensor feed needs lightweight format verification and rate limiting.

### Implement tiered CDS architectures matched to operational layers

The choice between hardware and software CDS is not binary — most deployments use hybrid architectures — but the selection is driven by classification level, threat model, physical environment, and whether cloud deployment is required.

**Combat Cloud (cloud-hosted operations):** Software CDS is viable and often preferred at this layer. Cloud environments can only use software CDS (custom hardware cannot run in public cloud). Cloud-native CDS handles domain separation between cloud accounts, regions, or tenancies at the same or adjacent classification levels.

**Kill Web (operational headquarters):** Hybrid architectures dominate. Hardware data diodes for high-assurance unidirectional sensor feeds (radar tracks, SIGINT, ISR imagery flowing upward from tactical collection to operational fusion). Software guards or diode messaging for bidirectional operational data exchange where the assurance requirement permits.

**MANET / Tactical Edge:** CDS at this layer must operate within severe Size, Weight, and Power (SWaP) constraints. Ruggedised hardware diodes in compact form factors handle one-way sensor export. Pre-validated message formats with cryptographic integrity verification allow the receiving side to perform lightweight structural conformance and signature checks rather than full content transformation — the message schema is sufficiently constrained that schema validation and integrity verification provide adequate destination protection without the latency of deep content inspection.

**Critical principle:** Cloud-hosted data connecting to physically isolated networks always traverses a hardware boundary regardless of operational layer. Software CDS within the cloud handles cloud-to-cloud domain separation; hardware CDS handles the transition from cloud to physical isolation.

### Automate data flow policies

Express cross-domain data flow rules as machine-readable policies that can be updated without code changes. When operational requirements change (e.g., a new coalition partner is added), policy updates should propagate to all CDS instances without manual reconfiguration.

In practice, this means:

- Policies expressed as declarative rules (not embedded in CDS firmware or application code)
- A policy distribution mechanism that pushes updates to CDS instances
- Version control and audit trail for all policy changes
- Testing/validation of policy changes before deployment (policy changes that affect CDS behaviour may require re-accreditation depending on the accreditation framework)

Consider implementing a query and data proxy layer that automates the integration with CDS — rather than requiring every data consumer to understand how to format requests for the CDS, the proxy abstracts the CDS interaction and presents a standard API to consumers.

### Support standing requirements across classification boundaries

In operational practice, data flow across a CDS is not always initiated by the producer. A higher classification layer — such as a SECRET operational headquarters — may publish a standing requirement to a lower classification layer: "notify me when any sensor detects vehicle movement in grid square XY." The lower layer evaluates incoming data against the standing requirement locally and pushes matching data through the CDS only when the criteria are met.

This is the reverse of the typical push model — the consumer defines what it needs, and the producer (or an automated filter at the producer's boundary) fulfils the requirement when data matches. This pattern is critical for ISR tasking, where a collection manager at SECRET defines requirements that tactical sensors at RESTRICTED fulfil.

Implement standing requirements as event-driven filters deployed at the producer side of the CDS. The filter evaluates incoming data against registered standing requirements and initiates cross-domain transfer only for matching data. This:

- Reduces CDS throughput (only relevant data crosses)
- Reduces latency (no human in the loop for routine matches)
- Aligns with how military tasking actually works — the requirement flows down, the data flows up

### Design for the latency trade-off between inspection thoroughness and operational tempo

CDS architectures operate in one of two fundamental modes, and the choice has direct consequences for both security assurance and mission utility:

**Store-and-forward:** Data is received by the CDS, held in a staging area, processed through the full treatment pipeline, and forwarded to the destination only after approval. Source and destination are not connected in real time. This mode supports the deepest inspection — CDR, multiple anti-virus engines, format conversion, human review where required — because the CDS has time to fully process each item before delivery. Latency ranges from seconds (fully automated, simple content) to hours or days (human-in-the-loop review of ambiguous or high-risk content).

**Real-time (streaming):** Data flows through the CDS with minimal buffering, approximating continuous connectivity between source and destination. Inspection depth is inherently limited — the CDS cannot fully inspect content it has not fully received. Treatments are restricted to lightweight format verification, schema validation against pre-approved message types, label checking, and rate limiting. The residual risk is higher than store-and-forward, accepted in exchange for the operational capability that real-time data provides.

Real-time mode is appropriate for:

- Sensor feeds (radar tracks, SIGINT, full-motion video)
- Cross-domain chat and messaging
- Real-time situational awareness (common operating picture updates)
- Fire-control data flows where latency directly affects lethality

The mesh proxy pattern described above naturally supports store-and-forward for query/response interactions. For streaming data, the CDS must be configured with pre-approved message schemas that allow lightweight validation without full content inspection.

### Validate data quality after cross-domain transit

Data that crosses a classification boundary through a CDS may be transformed (redacted, filtered, format-converted) during transit. Validate that the data product's quality characteristics are still accurate after transformation — redaction may reduce completeness, format conversion may introduce precision loss. Update quality metadata in the destination domain's catalogue to reflect post-transit quality.

## Review questions

- Is there a validated CDS at every risk boundary where data must flow?
- Have risk boundaries been identified and treated with CDS (particularly where environments at the same classification have materially different threat exposure)?
- Has the CDS type (hardware diode, software diode, diode messaging, bidirectional guard, or access solution) been selected for each boundary based on data flow direction, assurance requirement, and deployment environment?
- Is the assurance level of each CDS proportionate to the risk at that boundary (not over-engineered where unnecessary, not under-specified where critical)?
- Can data flow bidirectionally with appropriate controls for each direction (confidentiality treatments on the export path, integrity treatments on the import path)?
- Is the CDS architecture at each boundary hardware, software, or hybrid — and does that choice reflect the classification level, threat model, and deployment environment?
- Has each data type been assigned a CDS mode (store-and-forward or real-time) — accepting that real-time flows carry higher residual risk?
- Is a content treatment pipeline defined for each data type and flow direction, including format verification, content disarm and reconstruction, and label validation?
- Can cross-domain data flow policies be updated without code changes?
- Is CDS latency measured and within acceptable bounds for each operational use case?
- Is data quality re-validated after cross-domain transit, with catalogue metadata updated to reflect any transformation impact?
- Are attributes verified and screened prior to generating a new token for making authenticated requests through the CDS?
- Is the identity trust model established via pre-shared keys rather than real-time cross-boundary IdP communication?
- Can higher-classification consumers establish standing subscriptions to lower-classification data products through the CDS?
- Is a mesh proxy pattern implemented to abstract CDS interaction from data consumers and providers?
