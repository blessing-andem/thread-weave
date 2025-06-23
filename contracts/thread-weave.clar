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