# Reputation-Based Web3 Messaging Protocol

A Clarity smart contract that implements a decentralized messaging system with built-in reputation management, quality filtering, and community moderation features on the Stacks blockchain.

## Overview

This protocol addresses common issues in decentralized communication such as spam, low-quality content, and lack of trust mechanisms. It introduces a reputation system where users build trust over time through quality interactions and community validation.

## Key Features

### 🏆 Reputation System
- Users start with a base reputation score of 100
- Reputation affects messaging privileges and voting power
- Automatic decay mechanisms prevent reputation hoarding
- Dynamic thresholds for different message types

### 💰 Economic Incentives
- Stake-to-send mechanism requires users to lock STX tokens
- Quality-based stake recovery (good messages = full refund)
- Economic penalties for spam and low-quality content
- Minimum stake of 1 STX per message

### 🗳️ Community Moderation
- Quality voting system for message validation
- Spam reporting mechanisms
- Trust network establishment between users
- Collective quality assessment

### ⚡ Anti-Spam Protection
- Reputation-based rate limiting
- Daily message limits for new users
- Progressive penalties for spam behavior
- Economic barriers to mass messaging

## Contract Architecture

### Data Structures

#### User Reputation
```clarity
{
  score: uint,              // Current reputation score
  messages-sent: uint,      // Total messages sent
  messages-received: uint,  // Total messages received
  spam-reports: uint,       // Number of spam reports
  quality-score: uint,      // Average quality rating
  last-activity: uint,      // Last activity block height
  stake-locked: uint        // Total STX locked in stakes
}
```

#### Messages
```clarity
{
  sender: principal,        // Message sender
  recipient: principal,     // Message recipient
  content-hash: (buff 32),  // IPFS/content hash
  timestamp: uint,          // Block height when sent
  quality-votes: uint,      // Positive quality votes
  spam-reports: uint,       // Spam reports received
  stake-amount: uint,       // STX staked for this message
  message-type: string,     // "direct" or "broadcast"
  trust-required: uint      // Minimum reputation needed
}
```

#### Trust Network
```clarity
{
  trust-level: uint,        // Trust level (0-100)
  created-at: uint          // When trust was established
}
```

## Core Functions

### Public Functions

#### `initialize-reputation()`
Sets up initial reputation for a new user.
- **Starting reputation**: 100 points
- **Required**: First-time users only
- **Gas cost**: Low

#### `send-message(recipient, content-hash, message-type, stake-amount)`
Sends a message with reputation and stake requirements.
- **Parameters**:
  - `recipient`: Target user's principal
  - `content-hash`: 32-byte hash of message content
  - `message-type`: "direct" or "broadcast"
  - `stake-amount`: STX to stake (minimum 1 STX)
- **Requirements**:
  - Sufficient reputation (50+ for direct, 100+ for broadcast)
  - Minimum stake amount
  - Rate limit compliance
- **Returns**: Message ID

#### `vote-quality(message-id, vote-type)`
Vote on message quality or report spam.
- **Parameters**:
  - `message-id`: ID of message to vote on
  - `vote-type`: "quality" or "spam"
- **Requirements**:
  - Voter reputation ≥ 75
  - One vote per message per user
- **Effect**: Updates message quality metrics

#### `trust-user(trusted-user, trust-level)`
Establish trust relationship with another user.
- **Parameters**:
  - `trusted-user`: Principal to trust
  - `trust-level`: Trust level (0-100)
- **Requirements**:
  - Cannot trust yourself
  - Valid trust level range

#### `claim-stake(message-id)`
Recover staked STX based on message quality.
- **Parameters**:
  - `message-id`: ID of message to claim stake for
- **Requirements**:
  - Must be the original staker
  - Message must have received votes
- **Returns**:
  - **>60% quality**: Full stake refund
  - **≤60% quality**: 50% stake refund

### Read-Only Functions

#### `get-reputation(user)`
Returns complete reputation data for a user.

#### `get-trust-level(truster, trusted)`
Returns trust level between two users.

#### `get-message-quality(message-id)`
Returns quality percentage for a message.

#### `can-send-message(user)`
Checks if user meets minimum reputation requirements.

## Reputation Mechanics

### Reputation Thresholds
- **Minimum to send messages**: 50 points
- **Minimum for broadcasts**: 100 points
- **Minimum to vote**: 75 points

### Quality Assessment
- Messages are rated by community votes
- Quality ratio = quality votes / (quality votes + spam reports)
- >60% quality ratio considered "good"
- <60% quality ratio incurs stake penalty

### Rate Limiting
- New users: 10 messages per day maximum
- Daily limits reset automatically
- Higher reputation may allow more messages

## Economic Model

### Staking Mechanism
1. **Stake Required**: Minimum 1 STX per message
2. **Lock Period**: Until quality assessment complete
3. **Recovery**: Based on community quality rating
4. **Penalties**: Low-quality messages forfeit 50% of stake

### Incentive Alignment
- **Quality Content**: Full stake recovery + reputation boost
- **Spam/Low Quality**: Stake penalty + reputation loss
- **Community Participation**: Voting rewards reputation
- **Trust Building**: Gradual reputation accumulation

## Usage Examples

### Initialize and Send First Message
```clarity
;; Initialize reputation
(contract-call? .reputation-messaging initialize-reputation)

;; Send a direct message with 1 STX stake
(contract-call? .reputation-messaging send-message 
  'SP1234567890 
  0x1234567890abcdef1234567890abcdef12345678 
  "direct" 
  u1000000)
```

### Vote on Message Quality
```clarity
;; Vote that message #1 is high quality
(contract-call? .reputation-messaging vote-quality u1 "quality")

;; Report message #2 as spam
(contract-call? .reputation-messaging vote-quality u2 "spam")
```

### Establish Trust Network
```clarity
;; Trust user with 80% confidence
(contract-call? .reputation-messaging trust-user 'SP9876543210 u80)
```

### Claim Stake Back
```clarity
;; Claim stake for message #1 after community voting
(contract-call? .reputation-messaging claim-stake u1)
```

## Security Considerations

### Attack Vectors
- **Sybil Attacks**: Mitigated by economic staking requirements
- **Reputation Manipulation**: Rate limiting and decay mechanisms
- **Spam Flooding**: Economic barriers and community moderation
- **Vote Manipulation**: Reputation requirements for voting

### Best Practices
- Start with small stakes to build reputation
- Engage authentically with the community
- Report spam to maintain system quality
- Build trust networks gradually

## Deployment

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Sufficient STX for deployment and testing
- Clarity development environment

### Deployment Steps
1. Compile contract with Clarity tools
2. Deploy to Stacks blockchain
3. Initialize first users' reputations
4. Begin community-driven quality assessment

## Future Enhancements

### Planned Features
- **Reputation Decay**: Automatic score reduction over time
- **Advanced Filtering**: Content-based spam detection
- **Rewards System**: Token incentives for quality content
- **Governance**: Community-driven parameter updates
- **Integration**: Cross-protocol reputation portability

### Scalability
- Message content stored off-chain (IPFS)
- Only hashes and metadata on-chain
- Efficient reputation calculations
- Batch operations for gas optimization

## Contributing

Contributions welcome! Areas of focus:
- Gas optimization
- Additional quality metrics
- Enhanced anti-spam measures
- User experience improvements
- Integration with other Web3 protocols
