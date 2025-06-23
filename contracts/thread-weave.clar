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