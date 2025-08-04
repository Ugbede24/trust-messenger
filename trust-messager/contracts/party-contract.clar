;; Reputation-Based Web3 Messaging Protocol
;; Focus: Trust scores, quality filtering, community moderation

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOW_REPUTATION (err u101))
(define-constant ERR_RATE_LIMITED (err u102))
(define-constant ERR_INSUFFICIENT_STAKE (err u103))
(define-constant ERR_MESSAGE_NOT_FOUND (err u104))

;; Reputation thresholds
(define-constant MIN_REPUTATION_TO_MESSAGE u50)
(define-constant MIN_REPUTATION_FOR_BROADCAST u100)
(define-constant REPUTATION_DECAY_RATE u1)
(define-constant SPAM_PENALTY u10)

;; Data Variables
(define-data-var next-message-id uint u1)
(define-data-var base-stake-amount uint u1000000) ;; 1 STX in microSTX

;; User reputation and trust system
(define-map user-reputation
  { user: principal }
  {
    score: uint,
    messages-sent: uint,
    messages-received: uint,
    spam-reports: uint,
    quality-score: uint,
    last-activity: uint,
    stake-locked: uint
  })

;; Message with quality metrics
(define-map messages
  { id: uint }
  {
    sender: principal,
    recipient: principal,
    content-hash: (buff 32),
    timestamp: uint,
    quality-votes: uint,
    spam-reports: uint,
    stake-amount: uint,
    message-type: (string-ascii 10),
    trust-required: uint
  })

;; Trust relationships
(define-map trust-network
  { truster: principal, trusted: principal }
  { trust-level: uint, created-at: uint })

;; Quality voting
(define-map message-votes
  { voter: principal, message-id: uint }
  { vote-type: (string-ascii 10), timestamp: uint })

;; Rate limiting
(define-map user-rate-limits
  { user: principal }
  { messages-today: uint, last-reset: uint })

;; Staking for message quality
(define-map message-stakes
  { message-id: uint }
  { staker: principal, amount: uint, claimed: bool })

;; Initialize user reputation
(define-public (initialize-reputation)
  (let ((user tx-sender))
    (map-set user-reputation
      { user: user }
      {
        score: u100, ;; Starting reputation
        messages-sent: u0,
        messages-received: u0,
        spam-reports: u0,
        quality-score: u100,
        last-activity: stacks-block-height,
        stake-locked: u0
      })
    (ok true)))

;; Send message with reputation check and staking
(define-public (send-message (recipient principal) 
                           (content-hash (buff 32))
                           (message-type (string-ascii 10))
                           (stake-amount uint))
  (let ((sender tx-sender)
        (msg-id (get-next-message-id))
        (sender-rep (default-to { score: u0, messages-sent: u0, messages-received: u0, 
                                 spam-reports: u0, quality-score: u0, last-activity: u0, stake-locked: u0 }
                                (map-get? user-reputation { user: sender })))
        (required-trust (if (is-eq message-type "broadcast") MIN_REPUTATION_FOR_BROADCAST MIN_REPUTATION_TO_MESSAGE)))
    
    ;; Check reputation threshold
    (asserts! (>= (get score sender-rep) required-trust) ERR_LOW_REPUTATION)
    
    ;; Check rate limits
    (try! (check-rate-limit sender))
    
    ;; Require minimum stake for quality assurance
    (asserts! (>= stake-amount (var-get base-stake-amount)) ERR_INSUFFICIENT_STAKE)
    
    ;; Lock stake
    (try! (stx-transfer? stake-amount sender (as-contract tx-sender)))
    
    ;; Store message
    (map-set messages
      { id: msg-id }
      {
        sender: sender,
        recipient: recipient,
        content-hash: content-hash,
        timestamp: stacks-block-height,
        quality-votes: u0,
        spam-reports: u0,
        stake-amount: stake-amount,
        message-type: message-type,
        trust-required: required-trust
      })
    
    ;; Store stake info
    (map-set message-stakes
      { message-id: msg-id }
      { staker: sender, amount: stake-amount, claimed: false })
    
    ;; Update sender reputation
    (map-set user-reputation
      { user: sender }
      (merge sender-rep {
        messages-sent: (+ (get messages-sent sender-rep) u1),
        last-activity: stacks-block-height,
        stake-locked: (+ (get stake-locked sender-rep) stake-amount)
      }))
    
    ;; Update rate limit
    (update-rate-limit sender)
    
    (print { 
      event: "reputation-message", 
      id: msg-id, 
      sender: sender, 
      recipient: recipient,
      stake: stake-amount,
      reputation: (get score sender-rep)
    })
    
    (ok msg-id)))

;; Vote on message quality
(define-public (vote-quality (message-id uint) (vote-type (string-ascii 10)))
  (let ((voter tx-sender)
        (voter-rep (get score (default-to { score: u0, messages-sent: u0, messages-received: u0, 
                                           spam-reports: u0, quality-score: u0, last-activity: u0, stake-locked: u0 }
                                          (map-get? user-reputation { user: voter })))))
    
    ;; Only trusted users can vote
    (asserts! (>= voter-rep u75) ERR_LOW_REPUTATION)
    
    ;; Prevent duplicate voting
    (asserts! (is-none (map-get? message-votes { voter: voter, message-id: message-id })) ERR_NOT_AUTHORIZED)
    
    ;; Record vote
    (map-set message-votes
      { voter: voter, message-id: message-id }
      { vote-type: vote-type, timestamp: stacks-block-height })
    
    ;; Update message metrics
    (match (map-get? messages { id: message-id })
      msg (let ((updated-msg (if (is-eq vote-type "quality")
                               (merge msg { quality-votes: (+ (get quality-votes msg) u1) })
                               (merge msg { spam-reports: (+ (get spam-reports msg) u1) }))))
            (map-set messages { id: message-id } updated-msg)
            (ok true))
      ERR_MESSAGE_NOT_FOUND)))

;; Establish trust relationship
(define-public (trust-user (trusted-user principal) (trust-level uint))
  (let ((truster tx-sender))
    (asserts! (<= trust-level u100) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq truster trusted-user)) ERR_NOT_AUTHORIZED)
    
    (map-set trust-network
      { truster: truster, trusted: trusted-user }
      { trust-level: trust-level, created-at: stacks-block-height })
    
    (ok true)))

;; Claim stake back if message has good quality score
(define-public (claim-stake (message-id uint))
  (match (map-get? message-stakes { message-id: message-id })
    stake-info 
      (match (map-get? messages { id: message-id })
        msg (let ((quality-ratio (if (> (+ (get quality-votes msg) (get spam-reports msg)) u0)
                                   (/ (* (get quality-votes msg) u100) 
                                      (+ (get quality-votes msg) (get spam-reports msg)))
                                   u50)))
              (asserts! (is-eq tx-sender (get staker stake-info)) ERR_NOT_AUTHORIZED)
              (asserts! (not (get claimed stake-info)) ERR_NOT_AUTHORIZED)
              
              ;; Mark as claimed
              (map-set message-stakes 
                { message-id: message-id }
                (merge stake-info { claimed: true }))
              
              ;; Return stake if quality is good (>60%)
              (if (> quality-ratio u60)
                (try! (as-contract (stx-transfer? (get amount stake-info) tx-sender (get staker stake-info))))
                ;; Penalty for low quality - only return 50%
                (try! (as-contract (stx-transfer? (/ (get amount stake-info) u2) tx-sender (get staker stake-info)))))
              
              (ok quality-ratio))
        ERR_MESSAGE_NOT_FOUND)
    ERR_MESSAGE_NOT_FOUND))

;; Helper functions
(define-private (get-next-message-id)
  (let ((current-id (var-get next-message-id)))
    (var-set next-message-id (+ current-id u1))
    current-id))

(define-private (check-rate-limit (user principal))
  (let ((limits (default-to { messages-today: u0, last-reset: u0 }
                            (map-get? user-rate-limits { user: user })))
        (today (/ stacks-block-height u144))) ;; Rough daily blocks
    
    (if (> today (get last-reset limits))
      ;; Reset daily counter
      (begin
        (map-set user-rate-limits { user: user } { messages-today: u0, last-reset: today })
        (ok true))
      ;; Check if under limit (max 10 per day for new users)
      (if (< (get messages-today limits) u10)
        (ok true)
        ERR_RATE_LIMITED))))

(define-private (update-rate-limit (user principal))
  (let ((limits (default-to { messages-today: u0, last-reset: u0 }
                            (map-get? user-rate-limits { user: user }))))
    (map-set user-rate-limits 
      { user: user } 
      (merge limits { messages-today: (+ (get messages-today limits) u1) }))
    true))

;; Read-only functions
(define-read-only (get-reputation (user principal))
  (map-get? user-reputation { user: user }))

(define-read-only (get-trust-level (truster principal) (trusted principal))
  (map-get? trust-network { truster: truster, trusted: trusted }))

(define-read-only (get-message-quality (message-id uint))
  (match (map-get? messages { id: message-id })
    msg (let ((total-votes (+ (get quality-votes msg) (get spam-reports msg))))
          (if (> total-votes u0)
            (some (/ (* (get quality-votes msg) u100) total-votes))
            none))
    none))

(define-read-only (can-send-message (user principal))
  (let ((rep (get score (default-to { score: u0, messages-sent: u0, messages-received: u0, 
                                     spam-reports: u0, quality-score: u0, last-activity: u0, stake-locked: u0 }
                                    (map-get? user-reputation { user: user })))))
    (>= rep MIN_REPUTATION_TO_MESSAGE)))