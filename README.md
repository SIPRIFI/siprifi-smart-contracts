# BlockchainCDS – Detailed Technical Explanation

## 1. Detailed Technical Explanation (English)

This smart contract implements a minimal, fully collateralized Credit Default Swap (CDS) mechanism on Ethereum. It allows two parties to enter a bilateral risk-transfer agreement where one party sells protection against a predefined event and another party buys that protection by paying periodic premiums.

The design intentionally prioritizes simplicity, capital safety, and correctness. As an MVP, the resolution of whether the insured event occurred is centralized and controlled by a trusted organization address. This avoids ambiguity, manipulation, and insolvency risks that often appear in early-stage decentralized insurance designs.

---

### Contract Structure and Types

The contract defines an enum called `CDSStatus`, which models the lifecycle of a CDS contract. The possible states are:

- Open: The CDS has been created by the seller but has not yet been purchased.
- Active: A buyer has purchased protection and the CDS is live.
- Triggered: The insured event has occurred and the buyer has been paid.
- Expired: The CDS reached maturity without the event occurring.

A CDS is represented by a struct that stores all economic and temporal parameters of the agreement. This includes the seller and buyer addresses, a human-readable description of the insured event, the notional amount insured, the collateral locked by the seller, the premium paid periodically by the buyer, the time interval between premiums, timestamps for tracking payments and maturity, the current state of the CDS, and a boolean indicating whether the event occurred.

---

### Storage and Roles

The contract stores a single `organization` address. This address represents a trusted authority (such as a company, DAO, or multisig) that has the exclusive right to resolve whether an insured event has occurred.

Each CDS is stored in a mapping indexed by an incremental identifier. The `cdsCount` variable tracks the total number of CDS contracts created.

---

### Modifiers and Access Control

Several modifiers enforce correct behavior and access control:

- `onlyOrganization` restricts certain functions to the organization address.
- `onlyBuyer` ensures that only the registered buyer can pay premiums.
- `active` ensures that certain actions can only occur when the CDS is in the Active state.

These modifiers prevent unauthorized access and invalid state transitions.

---

### CDS Creation

The `createCDS` function allows a seller to create a CDS. The seller must deposit collateral equal to the notional amount. This enforces full collateralization and guarantees that the buyer can always be paid if the event occurs.

The seller specifies the insured event, notional amount, premium size, premium payment interval, and maturity timestamp. Once created, the CDS is stored in the Open state and awaits a buyer.

---

### Buying Protection

The `buyCDS` function allows a buyer to enter the CDS before maturity. Once called, the buyer address is set, the CDS status changes from Open to Active, and the premium payment timer begins.

No funds are transferred at this stage; the buyer commits to paying premiums over time.

---

### Premium Payments

The `payPremium` function allows the buyer to pay the periodic premium. The function enforces:

- Exact premium amount
- Correct timing based on the premium interval
- That the CDS has not yet matured

Premium payments are transferred directly to the seller. Each payment updates the timestamp used to calculate the next payment window.

---

### Event Resolution (Centralized)

The `resolveEvent` function is the core settlement mechanism. It can only be called by the organization while the CDS is active and before maturity.

If the organization declares that the event occurred:
- The CDS is marked as Triggered
- The buyer receives the full notional amount from the locked collateral

If the organization declares that the event did not occur:
- The CDS is marked as Expired
- The seller retrieves the locked collateral

This design ensures a single, authoritative resolution path and avoids disputes.

---

### Expiration Fallback

If the maturity date passes without the organization resolving the event, anyone can call `expireCDS`. This function safely expires the CDS and returns the collateral to the seller.

This prevents funds from becoming locked indefinitely due to inactivity or organizational failure.

---

### Design Philosophy

This contract intentionally avoids:
- Partial collateralization
- Algorithmic or subjective event resolution
- Complex liquidation logic
- External oracle dependencies

The result is a clear, auditable, and secure MVP that can later evolve toward decentralization.

---

## 2. Explicación Técnica (Español)

Este contrato inteligente implementa un Credit Default Swap (CDS) mínimo y totalmente colateralizado en Ethereum. Permite que dos partes firmen un acuerdo de transferencia de riesgo, donde una parte vende protección frente a un evento específico y la otra parte compra esa protección pagando primas periódicas.

El diseño está pensado como un MVP y por ello la resolución del evento está centralizada en una organización de confianza. Esto evita ambigüedades, disputas y riesgos de insolvencia, facilitando además auditorías y validación off-chain.

---

### Estructura General

El contrato define un ciclo de vida claro mediante el enum `CDSStatus`. Un CDS puede estar abierto, activo, activado por evento o expirado. Todas las transiciones están controladas y verificadas en el contrato.

Cada CDS almacena toda la información económica y temporal necesaria: vendedor, comprador, descripción del evento, monto asegurado, colateral bloqueado, prima, intervalo de pago, vencimiento y estado actual.

---

### Colateralización Total

El vendedor debe depositar un colateral exactamente igual al monto asegurado. Esto garantiza que, si el evento ocurre, el comprador siempre recibirá el pago completo sin depender de terceros o liquidez externa.

---

### Primas y Flujo Económico

El comprador paga primas periódicas al vendedor mientras el CDS esté activo. El contrato impone el importe exacto y el momento correcto del pago. Las primas se transfieren directamente al vendedor sin intermediarios.

---

### Resolución del Evento

Solo la organización puede decidir si el evento ocurrió o no. Si ocurrió, el comprador recibe el monto asegurado. Si no ocurrió, el colateral vuelve al vendedor.

Este enfoque centralizado es deliberado y adecuado para una primera versión del protocolo.

---

### Expiración de Seguridad

Si nadie resuelve el evento antes del vencimiento, cualquier usuario puede cerrar el CDS y devolver el colateral al vendedor, evitando fondos bloqueados.

---

## 3. Short Technical Summary (English)

BlockchainCDS is a fully collateralized CDS smart contract that enables on-chain risk transfer through periodic premium payments. Sellers lock full collateral upfront, buyers pay premiums over time, and a trusted organization resolves whether the insured event occurred.

The contract enforces strict state transitions, prevents undercollateralization, and includes a permissionless expiration fallback. It is designed as a secure MVP with a clear upgrade path toward decentralized governance and oracle-based resolution.

