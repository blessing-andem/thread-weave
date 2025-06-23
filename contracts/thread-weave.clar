;; ThreadWeave Protocol
;;
;; A next-generation decentralized social networking protocol built on Bitcoin's
;; security model via Stacks Layer 2. ThreadWeave revolutionizes online discourse
;; by combining cryptographic ownership, economic incentives, and community governance
;; to create sustainable, high-quality content ecosystems.
;;
;; Core Innovation:
;; - Bitcoin-anchored content ownership and reputation systems
;; - Economic value alignment through STX-based tipping and premium content
;; - Stake-weighted governance preventing spam and promoting quality discourse
;; - Nested threading architecture supporting complex conversation structures
;; - NFT-based achievement system rewarding viral and valuable contributions
;;
;; The protocol solves the traditional social media trilemma of scale, quality,
;; and monetization by leveraging Bitcoin's immutable ledger for trust,
;; Stacks' smart contract capabilities for complex interactions, and
;; token economics for sustainable creator compensation.
;;
;; Features:
;; - Premium Content Gating: Creators monetize exclusive threads and discussions
;; - Reputation-Based Governance: Stake-weighted voting ensures quality curation
;; - Tip Economy: Direct creator compensation through microtransactions
;; - NFT Milestones: Collectible achievements for viral content creators
;; - Anti-Spam Mechanics: Staking requirements filter low-quality participants
;; - Nested Reply System: Complex conversation threading with parent-child relationships

;; ERROR CONSTANTS
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))  
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-THREAD-LOCKED (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-INVALID-TIP (err u107))
(define-constant ERR-SELF-TIP (err u108))
(define-constant ERR-THREAD-NOT-PREMIUM (err u109))
(define-constant ERR-INSUFFICIENT-STAKE (err u110))
(define-constant ERR-INVALID-PARENT-REPLY (err u111))

;; PROTOCOL CONFIGURATION
(define-data-var thread-counter uint u0)
(define-data-var reply-counter uint u0)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum stake
(define-data-var platform-fee-rate uint u250)    ;; 2.5% platform fee
(define-data-var platform-treasury principal CONTRACT-OWNER)

;; CORE DATA STRUCTURES

;; Thread storage with premium content gating
(define-map threads
  { thread-id: uint }
  {
    author: principal,
    title: (string-utf8 256),
    content: (string-utf8 2048),
    is-premium: bool,
    premium-price: uint,
    created-at: uint,
    upvotes: uint,
    downvotes: uint,
    tips-received: uint,
    is-locked: bool,
    reply-count: uint
  }
)

;; Nested reply system with thread association
(define-map replies
  { reply-id: uint }
  {
    thread-id: uint,
    author: principal,
    content: (string-utf8 1024),
    created-at: uint,
    upvotes: uint,
    downvotes: uint,
    tips-received: uint,
    parent-reply-id: (optional uint)
  }
)

;; Comprehensive reputation tracking system
(define-map user-reputation
  { user: principal }
  {
    total-upvotes: uint,
    total-downvotes: uint,
    threads-created: uint,
    replies-created: uint,
    tips-sent: uint,
    tips-received: uint,
    staked-amount: uint,
    reputation-score: uint
  }
)

;; Voting system with duplicate prevention
(define-map thread-votes
  { thread-id: uint, voter: principal }
  { vote-type: bool }
)

(define-map reply-votes
  { reply-id: uint, voter: principal }
  { vote-type: bool }
)

;; Premium access control mechanism
(define-map premium-access
  { thread-id: uint, user: principal }
  { purchased-at: uint }
)

;; Staking mechanism for platform participation
(define-map user-stakes
  { user: principal }
  { amount: uint, locked-until: uint }
)

;; Thread boosting with STX allocation
(define-map thread-boosts
  { thread-id: uint }
  { boost-amount: uint, boosted-by: (list 20 principal) }
)

;; NFT ACHIEVEMENT SYSTEM
(define-non-fungible-token thread-milestone uint)

;; UTILITY FUNCTIONS

(define-private (get-current-time)
  stacks-block-height
)

(define-private (calculate-reputation-score 
    (upvotes uint) 
    (downvotes uint) 
    (thread-count uint) 
    (reply-count uint))
  (let ((base-score (+ (* upvotes u10) (* thread-count u5) (* reply-count u2))))
    (if (> downvotes u0)
      (/ (* base-score u100) (+ u100 (* downvotes u5)))
      base-score
    )
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-private (is-user-staked (user principal))
  (let ((stake-info (map-get? user-stakes { user: user })))
    (match stake-info
      stake (and 
              (>= (get amount stake) (var-get min-stake-amount))
              (>= (get-current-time) (get locked-until stake)))
      false
    )
  )
)

(define-private (is-valid-parent-reply (parent-reply-id uint) (thread-id uint))
  (match (map-get? replies { reply-id: parent-reply-id })
    reply-info (is-eq (get thread-id reply-info) thread-id)
    false
  )
)

(define-private (is-valid-reply-id (reply-id uint))
  (is-some (map-get? replies { reply-id: reply-id }))
)

(define-private (is-valid-thread-id (thread-id uint))
  (and 
    (> thread-id u0) 
    (<= thread-id (var-get thread-counter))
    (is-some (map-get? threads { thread-id: thread-id })))
)

(define-private (is-valid-parent-reply-enhanced (parent-reply-id uint) (thread-id uint))
  (and 
    (> parent-reply-id u0)
    (<= parent-reply-id (var-get reply-counter))
    (is-valid-parent-reply parent-reply-id thread-id))
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-thread (thread-id uint))
  (map-get? threads { thread-id: thread-id })
)

(define-read-only (get-reply (reply-id uint))
  (map-get? replies { reply-id: reply-id })
)

(define-read-only (get-user-reputation (user principal))
  (default-to
    {
      total-upvotes: u0,
      total-downvotes: u0,
      threads-created: u0,
      replies-created: u0,
      tips-sent: u0,
      tips-received: u0,
      staked-amount: u0,
      reputation-score: u0
    }
    (map-get? user-reputation { user: user })
  )
)

(define-read-only (get-thread-count)
  (var-get thread-counter)
)

(define-read-only (get-reply-count)
  (var-get reply-counter)
)

(define-read-only (has-premium-access (thread-id uint) (user principal))
  (let ((thread-info (get-thread thread-id)))
    (match thread-info
      thread (if (get is-premium thread)
               (is-some (map-get? premium-access { thread-id: thread-id, user: user }))
               true)
      false
    )
  )
)

(define-read-only (get-user-vote-on-thread (thread-id uint) (user principal))
  (map-get? thread-votes { thread-id: thread-id, voter: user })
)

(define-read-only (get-user-vote-on-reply (reply-id uint) (user principal))
  (map-get? reply-votes { reply-id: reply-id, voter: user })
)

(define-read-only (get-thread-boost (thread-id uint))
  (default-to
    { boost-amount: u0, boosted-by: (list) }
    (map-get? thread-boosts { thread-id: thread-id })
  )
)

;; CONTENT CREATION FUNCTIONS

;; Create new discussion thread with optional premium gating
(define-public (create-thread 
    (title (string-utf8 256)) 
    (content (string-utf8 2048)) 
    (is-premium bool) 
    (premium-price uint))
  (let ((thread-id (+ (var-get thread-counter) u1))
        (current-time (get-current-time)))
    
    ;; Validation checks
    (asserts! (is-user-staked tx-sender) ERR-INSUFFICIENT-STAKE)
    (asserts! (> (len title) u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len content) u0) ERR-INVALID-AMOUNT)
    (asserts! (or (not is-premium) (> premium-price u0)) ERR-INVALID-AMOUNT)
    
    ;; Create thread record
    (map-set threads
      { thread-id: thread-id }
      {
        author: tx-sender,
        title: title,
        content: content,
        is-premium: is-premium,
        premium-price: premium-price,
        created-at: current-time,
        upvotes: u0,
        downvotes: u0,
        tips-received: u0,
        is-locked: false,
        reply-count: u0
      }
    )
    
    ;; Update creator reputation metrics
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            threads-created: (+ (get threads-created current-rep) u1),
            reputation-score: (calculate-reputation-score
              (get total-upvotes current-rep)
              (get total-downvotes current-rep)
              (+ (get threads-created current-rep) u1)
              (get replies-created current-rep)
            )
          }
        )
      )
    )
    
    (var-set thread-counter thread-id)
    (ok thread-id)
  )
)

;; Create threaded reply with comprehensive validation
(define-public (create-reply 
    (thread-id uint) 
    (content (string-utf8 1024)) 
    (parent-reply-id (optional uint)))
  (let ((reply-id (+ (var-get reply-counter) u1))
        (current-time (get-current-time))
        (thread-info (unwrap! (get-thread thread-id) ERR-NOT-FOUND)))
    
    ;; Core validation
    (asserts! (is-user-staked tx-sender) ERR-INSUFFICIENT-STAKE)
    (asserts! (not (get is-locked thread-info)) ERR-THREAD-LOCKED)
    (asserts! (> (len content) u0) ERR-INVALID-AMOUNT)
    
    ;; Validate parent reply if specified
    (let ((validated-parent-reply-id 
           (match parent-reply-id
             parent-id (begin
                         (asserts! (> parent-id u0) ERR-INVALID-PARENT-REPLY)
                         (asserts! (<= parent-id (var-get reply-counter)) ERR-INVALID-PARENT-REPLY)
                         (asserts! (is-valid-parent-reply parent-id thread-id) ERR-INVALID-PARENT-REPLY)
                         (some parent-id))
             none)))
      
      ;; Premium access validation
      (if (get is-premium thread-info)
        (asserts! (has-premium-access thread-id tx-sender) ERR-THREAD-NOT-PREMIUM)
        true
      )
      
      ;; Create reply record
      (map-set replies
        { reply-id: reply-id }
        {
          thread-id: thread-id,
          author: tx-sender,
          content: content,
          created-at: current-time,
          upvotes: u0,
          downvotes: u0,
          tips-received: u0,
          parent-reply-id: validated-parent-reply-id
        }
      )
      
      ;; Update thread reply counter
      (map-set threads
        { thread-id: thread-id }
        (merge thread-info { reply-count: (+ (get reply-count thread-info) u1) })
      )
      
      ;; Update user reputation metrics
      (let ((current-rep (get-user-reputation tx-sender)))
        (map-set user-reputation
          { user: tx-sender }
          (merge current-rep
            {
              replies-created: (+ (get replies-created current-rep) u1),
              reputation-score: (calculate-reputation-score
                (get total-upvotes current-rep)
                (get total-downvotes current-rep)
                (get threads-created current-rep)
                (+ (get replies-created current-rep) u1)
              )
            }
          )
        )
      )
      
      (var-set reply-counter reply-id)
      (ok reply-id)
    )
  )
)

;; MONETIZATION FUNCTIONS

;; Purchase premium thread access with STX payment
(define-public (purchase-premium-access (thread-id uint))
  (let ((thread-info (unwrap! (get-thread thread-id) ERR-NOT-FOUND))
        (current-time (get-current-time)))
    
    (asserts! (get is-premium thread-info) ERR-THREAD-NOT-PREMIUM)
    (asserts! (is-none (map-get? premium-access { thread-id: thread-id, user: tx-sender })) ERR-UNAUTHORIZED)
    
    (let ((price (get premium-price thread-info))
          (author (get author thread-info))
          (platform-fee (calculate-platform-fee price))
          (author-payment (- price platform-fee)))
      
      ;; Process STX payment to author
      (try! (stx-transfer? author-payment tx-sender author))
      
      ;; Platform fee to treasury
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
      
      ;; Grant premium access
      (map-set premium-access
        { thread-id: thread-id, user: tx-sender }
        { purchased-at: current-time }
      )
      
      (ok true)
    )
  )
)

;; VOTING SYSTEM

;; Vote on thread content with reputation impact
(define-public (vote-thread (thread-id uint) (is-upvote bool))
  (let ((thread-info (unwrap! (get-thread thread-id) ERR-NOT-FOUND))
        (existing-vote (map-get? thread-votes { thread-id: thread-id, voter: tx-sender })))
    
    (asserts! (is-user-staked tx-sender) ERR-INSUFFICIENT-STAKE)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (not (is-eq tx-sender (get author thread-info))) ERR-UNAUTHORIZED)
    
    ;; Record vote
    (map-set thread-votes
      { thread-id: thread-id, voter: tx-sender }
      { vote-type: is-upvote }
    )
    
    ;; Update thread vote counts
    (let ((new-upvotes (if is-upvote (+ (get upvotes thread-info) u1) (get upvotes thread-info)))
          (new-downvotes (if is-upvote (get downvotes thread-info) (+ (get downvotes thread-info) u1))))
      
      (map-set threads
        { thread-id: thread-id }
        (merge thread-info
          {
            upvotes: new-upvotes,
            downvotes: new-downvotes
          }
        )
      )
      
      ;; Update author reputation
      (let ((author-rep (get-user-reputation (get author thread-info))))
        (map-set user-reputation
          { user: (get author thread-info) }
          (merge author-rep
            {
              total-upvotes: (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep)),
              total-downvotes: (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1)),
              reputation-score: (calculate-reputation-score
                (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep))
                (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1))
                (get threads-created author-rep)
                (get replies-created author-rep)
              )
            }
          )
        )
      )
    )
    
    (ok true)
  )
)

;; Vote on reply content with reputation impact
(define-public (vote-reply (reply-id uint) (is-upvote bool))
  (let ((reply-info (unwrap! (get-reply reply-id) ERR-NOT-FOUND))
        (existing-vote (map-get? reply-votes { reply-id: reply-id, voter: tx-sender })))
    
    (asserts! (is-user-staked tx-sender) ERR-INSUFFICIENT-STAKE)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (not (is-eq tx-sender (get author reply-info))) ERR-UNAUTHORIZED)
    
    ;; Record vote
    (map-set reply-votes
      { reply-id: reply-id, voter: tx-sender }
      { vote-type: is-upvote }
    )
    
    ;; Update reply vote counts
    (let ((new-upvotes (if is-upvote (+ (get upvotes reply-info) u1) (get upvotes reply-info)))
          (new-downvotes (if is-upvote (get downvotes reply-info) (+ (get downvotes reply-info) u1))))
      
      (map-set replies
        { reply-id: reply-id }
        (merge reply-info
          {
            upvotes: new-upvotes,
            downvotes: new-downvotes
          }
        )
      )
      
      ;; Update author reputation
      (let ((author-rep (get-user-reputation (get author reply-info))))
        (map-set user-reputation
          { user: (get author reply-info) }
          (merge author-rep
            {
              total-upvotes: (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep)),
              total-downvotes: (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1)),
              reputation-score: (calculate-reputation-score
                (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep))
                (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1))
                (get threads-created author-rep)
                (get replies-created author-rep)
              )
            }
          )
        )
      )
    )
    
    (ok true)
  )
)

;; TIPPING ECONOMY

;; Send STX tip to thread author with platform fee
(define-public (tip-thread (thread-id uint) (amount uint))
  (begin
    ;; Explicit validation of thread-id
    (asserts! (> thread-id u0) ERR-NOT-FOUND)
    (asserts! (<= thread-id (var-get thread-counter)) ERR-NOT-FOUND)
    
    (let ((thread-info (unwrap! (get-thread thread-id) ERR-NOT-FOUND))
          (author (get author thread-info)))
      
      (asserts! (> amount u0) ERR-INVALID-TIP)
      (asserts! (not (is-eq tx-sender author)) ERR-SELF-TIP)
      
      (let ((platform-fee (calculate-platform-fee amount))
            (author-payment (- amount platform-fee)))
        
        ;; Transfer tip to author
        (try! (stx-transfer? author-payment tx-sender author))
        
        ;; Platform fee collection
        (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
        
        ;; Update thread tip tracking
        (map-set threads
          { thread-id: thread-id }
          (merge thread-info { tips-received: (+ (get tips-received thread-info) amount) })
        )
        
        ;; Update reputation metrics
        (let ((sender-rep (get-user-reputation tx-sender))
              (author-rep (get-user-reputation author)))
          
          (map-set user-reputation
            { user: tx-sender }
            (merge sender-rep { tips-sent: (+ (get tips-sent sender-rep) amount) })
          )
          
          (map-set user-reputation
            { user: author }
            (merge author-rep { tips-received: (+ (get tips-received author-rep) amount) })
          )
        )
        
        (ok true)
      )
    )
  )
)

;; Send STX tip to reply author with platform fee
(define-public (tip-reply (reply-id uint) (amount uint))
  (let ((reply-info (unwrap! (get-reply reply-id) ERR-NOT-FOUND))
        (author (get author reply-info)))
    
    (asserts! (is-valid-reply-id reply-id) ERR-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-TIP)
    (asserts! (not (is-eq tx-sender author)) ERR-SELF-TIP)
    
    (let ((platform-fee (calculate-platform-fee amount))
          (author-payment (- amount platform-fee))
          (validated-reply-id reply-id))
      
      ;; Transfer tip to author
      (try! (stx-transfer? author-payment tx-sender author))
      
      ;; Platform fee collection
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
      
      ;; Update reply tip tracking
      (map-set replies
        { reply-id: validated-reply-id }
        (merge reply-info { tips-received: (+ (get tips-received reply-info) amount) })
      )
      
      ;; Update reputation metrics
      (let ((sender-rep (get-user-reputation tx-sender))
            (author-rep (get-user-reputation author)))
        
        (map-set user-reputation
          { user: tx-sender }
          (merge sender-rep { tips-sent: (+ (get tips-sent sender-rep) amount) })
        )
        
        (map-set user-reputation
          { user: author }
          (merge author-rep { tips-received: (+ (get tips-received author-rep) amount) })
        )
      )
      
      (ok true)
    )
  )
)

;; STAKING SYSTEM

;; Stake STX for platform participation privileges
(define-public (stake-tokens (amount uint) (lock-duration uint))
  (let ((current-stake (map-get? user-stakes { user: tx-sender }))
        (current-time (get-current-time)))
    
    (asserts! (>= amount (var-get min-stake-amount)) ERR-INSUFFICIENT-STAKE)
    (asserts! (> lock-duration u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update or create stake record
    (match current-stake
      existing-stake
      (map-set user-stakes
        { user: tx-sender }
        {
          amount: (+ (get amount existing-stake) amount),
          locked-until: (+ current-time lock-duration)
        }
      )
      (map-set user-stakes
        { user: tx-sender }
        {
          amount: amount,
          locked-until: (+ current-time lock-duration)
        }
      )
    )
    
    ;; Update staking reputation
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            staked-amount: (+ (get staked-amount current-rep) amount)
          }
        )
      )
    )
    
    (ok true)
  )
)

;; Withdraw staked STX after lock period expires
(define-public (unstake-tokens (amount uint))
  (let ((stake-info (unwrap! (map-get? user-stakes { user: tx-sender }) ERR-NOT-FOUND))
        (current-time (get-current-time)))
    
    (asserts! (>= current-time (get locked-until stake-info)) ERR-UNAUTHORIZED)
    (asserts! (<= amount (get amount stake-info)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Return STX to user
    (try! (as-contract (stx-transfer? amount tx-sender contract-caller)))
    
    ;; Update or remove stake record
    (let ((remaining-amount (- (get amount stake-info) amount)))
      (if (> remaining-amount u0)
        (map-set user-stakes
          { user: tx-sender }
          (merge stake-info { amount: remaining-amount })
        )
        (map-delete user-stakes { user: tx-sender })
      )
    )
    
    ;; Update reputation
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            staked-amount: (- (get staked-amount current-rep) amount)
          }
        )
      )
    )
    
    (ok true)
  )
)