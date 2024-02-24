## STORMBIT: A DECENTRALIZED LENDING PROTOCOL FOR CONSUMERS

  <img src="./docs/Logo.png" alt="Stormbit Logo" width="200" class="logo">

StormBit is a pioneering project developed during the Avalanche Frontier Hackathon, designed to revolutionize consumer lending on the Avalanche blockchain. It introduces a unique lending marketplace targeting the micro-lending sector, seamlessly connecting decentralized finance (DeFi) with real-world financial transactions.

## DOCUMENTATION

For detailed information about StormBit, please visit our comprehensive [StormBit Documentation](https://stormbit.gitbook.io/stormbit/)

## UI

To check the code for the UI : https://github.com/Quantum3-Labs/StormBit-monorepo/tree/dev/carlos

## Overview

StormBit aims to democratize access to credit, especially targeting the 99% who are traditionally underserved by conventional financial institutions. It offers various agreement types, enabling lenders and borrowers to interact transparently and efficiently in a decentralized environment.

## Architecture

### Actors

- **Lender**: A KYC-verified individual willing to contribute to a shared pool and participate in voting to approve or deny loans. Lenders have full control over their pool's - functionalities.
- **Borrower**: A KYC-verified individual seeking or currently managing a loan within a pool. Borrowers can oversee all aspects of their loans, including repayments.
- **User**: Non-KYC-verified accounts with the ability to view data on the app but limited interaction capabilities with most pools.
- **Pool Manager**: A KYC-verified user with the authority to vote on loan approvals within their designated pool.

### Governance & Loans Allocation

Loan allocation is governed by a voting process, with each loan request presented as a proposal on the Avalanche Fuji Testnet. The StormBitLending contract, inheriting necessary governance functionalities from OpenZeppelin, oversees this process. Key on-chain transactions include:

- **Proposal Creation**: Initiated when a borrower requests a loan, either by depositing collateral (NFT or ERC-20 tokens) or opting for a collateral-free agreement (Simple Agreement).
- **Casting Vote**: Exclusive to stakers, allowing them to vote on loan allocations.
- **Voting Cool Down Period**: Introduces a delay before considering a voter's input as valid, preventing potential voting power manipulation.

### Agreements on StormBit

StormBit offers three types of loan agreements:

- Simple Agreement: Focuses on trust and the borrower's reputation, allowing undercollateralized loans. It is streamlined for flexibility and simplicity, emphasizing financial terms over asset involvement.

  <img src="./docs/SimpleAgreement.png" alt="SimpleAgreement" >

- NFT Agreement: Uses NFTs as collateral, ensuring loan security. This agreement includes mechanisms for collateral management and secure NFT custody, allowing borrowers to reclaim their NFT upon fulfilling loan terms.

  <img src="./docs/NFTAgreement.png" alt="NFTAgreement" >

- FT Agreement: Requires collateral equal to or greater than the loan amount for security. It captures essential loan initiation details and manages collateral throughout the loan lifecycle.

  <img src="./docs/FTAgreement.png" alt="FTAgreement Logo" >

#### Security and Trust

All agreements undergo rigorous security audits, including fuzzing tests, to ensure the highest security standards. Additional checks, such as a voting power cooldown variable, are implemented to safeguard against malicious activities.

## How it works

#### Flow

StormBit facilitates credit access by offering diverse agreement types. Any KYC-verified user can request a loan and receive equitable treatment from the pool's owners, bridging the gap between DeFi and traditional finance.

#### Credit Score Composite

Refer to this [documentation](https://stormbit.gitbook.io/stormbit/credit-score-composite) for credit score assessement used by StormBit.

## Technologies and Innovations

Deployed on the Avalanche blockchain, StormBit leverages state-of-the-art technologies to enhance scalability and inclusivity:

- **Particle Auth**: Enables login via email or mobile, inviting Web2 users to participate in DeFi.

#### Particle Architecture

<img src="./docs/ParticleArchitecture.png" alt="Particle Architecture" >

#### Particle Integration on UI

<img src="./docs/Particle.png" alt="Particle Auth" width="290" >

- **Chainlink**: Integration of credit score with Chainlink Functions.

`StormBit, created with love by Q3 Labs during the Avalanche Frontier Hackathon, stands at the forefront of decentralized consumer lending, promising a more inclusive, secure, and transparent financial future`

Submitted for Avalanche hackathon : <img src="./docs/Avalanche.png" alt="Avalanche" width="40" >

## Contact

For any inquiries or further information, feel free to contact the StormBit team at contact@quantum3labs.com
