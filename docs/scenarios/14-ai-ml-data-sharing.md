# Scenario 14: Coalition AI/ML Training Data and Model Sharing

## Overview

NATO's Data Strategy for the Alliance (DaSA, 2025) and revised AI Strategy (2024) position AI as a critical capability for maintaining the Alliance's technological edge. AI systems require large, diverse datasets for training -- but the best training data is often classified, nationally controlled, and scattered across alliance members. Nations need to share training data, pre-trained models, and inference results while maintaining data provenance, enforcing originator controls, and ensuring responsible AI governance. The NATO Data and Artificial Intelligence Review Board (DARB) is developing certification standards, but the underlying data sharing challenge remains: you cannot train AI on data you cannot share.

## Problem Statement

Current coalition AI development faces a data paradox: AI models are only as good as their training data, but the most operationally relevant training data is classified and nationally controlled. Nations are reluctant to share training data that reveals collection capabilities, operational patterns, or intelligence sources. Even when willing, there is no standard mechanism to share training datasets with provenance tracking, access controls that persist through the ML pipeline, or audit trails showing which data trained which models. Federated learning offers a partial solution but introduces its own data security challenges around gradient sharing and model inversion attacks.

## Actors

### Data Contributing Nations
- **Role**: Provide training datasets from national sensors, intelligence, and operations
- **Types**: Satellite imagery, radar data, SIGINT, operational logs, maintenance records
- **Controls**: Each nation specifies how their data may be used for training
- **Constraint**: Training data may reveal collection capabilities or operational patterns

### AI Development Teams
- **Role**: Train, validate, and deploy AI/ML models for coalition use
- **Types**: National defence AI labs, NATO DIANA innovators, defence industry
- **Clearances**: Vary from UNCLASSIFIED (commercial AI teams) to TOP SECRET (national labs)
- **Constraint**: Need diverse, representative data for effective models

### Model Consumers
- **Role**: Deploy and use AI models in operational settings
- **Types**: Military commanders, targeting officers, intelligence analysts, autonomous systems
- **Constraint**: Must understand model provenance, limitations, and biases

### NATO DARB (Data and AI Review Board)
- **Role**: Certify responsible AI compliance
- **Responsibility**: Ensure models meet ethical, legal, and operational standards
- **Constraint**: Must be able to audit training data provenance without necessarily accessing content

## Scenario Flow

### Phase 1: Training Data Contribution

**Context**: NATO develops a coalition AI model for automated target recognition in satellite imagery. Five nations contribute labelled training data.

**Contributions**:

**Nation A (US)**: 50,000 labelled satellite images
```
Data Type: Electro-optical satellite imagery
Labels: Vehicle types (tank, APC, truck, artillery)
Classification: SECRET (imagery), CONFIDENTIAL (labels)
Releasability: REL TO NATO for model training
Restrictions: Raw imagery NOT to leave US-controlled infrastructure
              Labels may be used for federated training
              Model trained on this data: REL TO NATO
```

**Nation B (UK)**: 30,000 labelled radar images
```
Data Type: Synthetic aperture radar imagery
Labels: Vehicle types + concealment indicators
Classification: UK SECRET
Releasability: REL TO FVEY for model training
Restrictions: Raw imagery NOT to leave UK-controlled infrastructure
              Derived model weights: REL TO NATO
              Sensor parameters embedded in imagery MUST be stripped
```

**Nation C (France)**: 20,000 labelled images + terrain data
```
Data Type: Mixed EO/SAR with terrain context
Labels: Vehicle types + terrain classification
Classification: SECRET DEFENSE
Releasability: REL TO NATO for model training
Restrictions: Geographic locations in imagery MUST be anonymised
              Derived model weights: REL TO NATO
```

**DCS Application**: Each dataset wrapped in ZTDF with policies specifying permitted uses (training only, no direct viewing of content), permitted consumers (specific AI development teams), and derivative restrictions (what classification applies to models trained on this data).

### Phase 2: Federated Model Training

**Context**: Rather than centralising all data, nations train local model components and share model updates (federated learning).

**Federated Training Process**:
1. NATO distributes base model architecture to all participating nations
2. Each nation trains locally on their national data
3. Nations share model weight updates (gradients) -- NOT raw training data
4. Central aggregation server combines updates into improved global model
5. Updated global model distributed back to nations for next training round

**DCS Challenges**:
- Model gradients can potentially be used to reconstruct training data (model inversion attacks)
- Gradient updates must be protected with DCS -- classification based on the training data classification
- Each nation's gradient updates carry that nation's originator controls
- Aggregated model inherits the most restrictive policy of any contributing nation's data

**DCS Application**: Gradient updates wrapped in ZTDF with ABAC policies matching the training data classification. The aggregation server must be authorised to access gradients from all contributing nations. The resulting model is wrapped with a composite policy reflecting all contributors' restrictions.

### Phase 3: Model Validation and Certification

**Context**: Trained model must be validated against test data and certified by DARB before operational deployment.

**Validation Requirements**:
- Test against data from geographic regions NOT in training set (generalisation)
- Test against adversary countermeasures (concealment, decoys)
- Assess for bias (does model perform equally across terrain types, weather conditions?)
- Verify model does not memorise specific classified examples

**DARB Certification**:
- Review training data provenance: which nations contributed, what classifications
- Verify responsible AI compliance (explainability, fairness, accountability)
- Approve model for operational use with specified limitations
- Certify appropriate classification for the model itself

**DCS Application**: DARB auditors access training data provenance metadata (which datasets, classifications, nations) without accessing the raw training data. Model certification record wrapped in ZTDF with audit trail showing complete provenance chain.

### Phase 4: Operational Deployment

**Context**: Certified model deployed to coalition ISR processing pipeline.

**Deployment**:
```
Model: Coalition Target Recognition v2.3
Trained On: US, UK, FR, DE, CA contributed datasets
Classification: NATO SECRET (model weights)
Deployment: Coalition ISR processing nodes
Inference Output: Classification and confidence score per image
Output Classification: Inherits input imagery classification
Restrictions: Model weights NOT to be exported outside NATO
              Model NOT to be reverse-engineered or decompiled
              Inference results do NOT carry training data classification
```

**DCS Application**: Model binary wrapped in ZTDF restricting access to authorised deployment nodes. Inference results wrapped with the classification of the input imagery (not the training data). Audit trail links every inference to the model version and deployment node.

### Phase 5: Model Update and Retirement

**Context**: New training data available; model must be updated. Old model versions retired.

**Update Process**:
- New datasets contributed (potentially from additional nations)
- Federated retraining produces model v2.4
- DARB re-certifies updated model
- New model deployed; old model deprecated
- Old model versions retained for audit (what model was in use when a particular decision was made?)

**Retirement**:
- Retired models wrapped in ZTDF with "no operational use" policy
- Model weights retained for audit and historical analysis
- Training data contributions governed by original nation policies (retention, deletion)

## Operational Constraints

1. **Data Sovereignty**: Nations retain control over their training data at all times
2. **No Central Data Lake**: Training data stays on national infrastructure (federated approach)
3. **Provenance**: Complete audit trail from training data to operational inference
4. **Responsible AI**: DARB certification required before operational deployment
5. **Model Security**: Trained models are valuable assets -- model theft must be prevented
6. **Derivative Classification**: Models trained on classified data carry appropriate classification
7. **Inference Speed**: Operational models must perform inference with minimal latency

## Technical Challenges

1. **Federated Learning Security**: How to protect gradient updates from model inversion attacks?
2. **Provenance Tracking**: How to track which data trained which model version through retraining?
3. **Composite Policy**: How to compute the most restrictive policy across multiple contributors?
4. **Model Classification**: What classification does a model trained on multi-national classified data carry?
5. **Inference Classification**: Does inference output carry the training data classification or the input data classification?
6. **DARB Audit**: How to enable audit of training data provenance without accessing the data itself?
7. **Model Retirement**: How to ensure retired models are not used operationally while retaining for audit?

## Acceptance Criteria

### AC1: Data Sovereignty
- [ ] Training data remains on national infrastructure (not centralised)
- [ ] Each nation controls access to their contributed data
- [ ] Nations can withdraw data contributions (future training excluded)
- [ ] Data deletion requests honoured per national retention policies

### AC2: Federated Training
- [ ] Model training works without centralising raw data
- [ ] Gradient updates protected with DCS matching training data classification
- [ ] Aggregation server authorised to access all contributing nations' updates
- [ ] Training process logged for reproducibility

### AC3: Provenance Tracking
- [ ] Complete chain from training data to operational model
- [ ] Each model version linked to specific training data contributions
- [ ] Contributing nations identifiable for each model version
- [ ] Provenance metadata accessible to DARB without accessing raw data

### AC4: Model Access Control
- [ ] Model weights classified and access-controlled
- [ ] Model deployment restricted to authorised systems
- [ ] Model export prevented (cannot copy model outside authorised infrastructure)
- [ ] Model decompilation/reverse-engineering restricted

### AC5: Inference Output Management
- [ ] Inference results classified based on input data (not training data)
- [ ] Inference audit trail links result to model version and input
- [ ] Inference results carry DCS metadata for downstream use

### AC6: DARB Compliance
- [ ] DARB can audit training data provenance
- [ ] DARB can review model performance metrics
- [ ] DARB certification recorded in model metadata
- [ ] Operational use prevented until DARB certification complete

### AC7: Comprehensive Audit Trail
- [ ] Training data contributions logged
- [ ] Training runs logged (which data, which parameters, which model version)
- [ ] Model deployments logged
- [ ] Inference operations logged (at configurable granularity)
- [ ] Audit supports responsible AI compliance investigations

## Success Metrics

- **Data Availability**: Nations contribute sufficient training data for effective models
- **Model Performance**: Coalition models perform comparably to single-nation models
- **Data Sovereignty**: No nation's training data leaves their controlled infrastructure
- **Provenance**: Complete audit trail from data to deployment
- **Responsible AI**: All deployed models DARB-certified

## Out of Scope

- AI model architecture design
- Specific ML algorithm selection
- Autonomous weapons policy (legal/ethical matter)
- AI hardware acceleration
- Commercial AI platform procurement

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing -- training data is a form of shared asset
- **Scenario 10**: Sensor-to-shooter -- AI models deployed in the kill chain
- **Scenario 13**: Space domain awareness -- satellite imagery as training data

---
