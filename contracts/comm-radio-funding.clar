(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-station-exists (err u104))
(define-constant err-station-not-active (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-campaign-not-active (err u107))
(define-constant err-campaign-exists (err u108))
(define-constant err-invalid-duration (err u109))
(define-constant err-invalid-rating (err u110))
(define-constant err-already-rated (err u111))
(define-constant err-pool-exists (err u112))
(define-constant err-pool-not-found (err u113))
(define-constant err-invalid-rate (err u114))
(define-constant err-milestone-not-found (err u115))
(define-constant err-milestone-already-claimed (err u116))
(define-constant err-target-not-reached (err u117))
(define-constant err-invalid-milestone (err u118))

(define-data-var next-station-id uint u1)
(define-data-var next-campaign-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var min-subscription-amount uint u1000000)

(define-map stations
  { station-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    location: (string-ascii 64),
    is-active: bool,
    total-raised: uint,
    subscriber-count: uint,
    created-at: uint
  }
)

(define-map station-owners
  { owner: principal }
  { station-id: uint }
)

(define-map subscriptions
  { patron: principal, station-id: uint }
  {
    amount: uint,
    created-at: uint,
    last-payment: uint,
    is-active: bool
  }
)

(define-map campaigns
  { campaign-id: uint }
  {
    station-id: uint,
    title: (string-ascii 64),
    description: (string-ascii 256),
    target-amount: uint,
    raised-amount: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    creator: principal
  }
)

(define-map campaign-contributions
  { campaign-id: uint, contributor: principal }
  { amount: uint, block-height: uint }
)

(define-map matching-pools
  { campaign-id: uint }
  {
    sponsor: principal,
    rate: uint,
    cap: uint,
    remaining: uint,
    active: bool,
    created-at: uint
  }
)

(define-map campaign-match-stats
  { campaign-id: uint }
  { total-matched: uint }
)

(define-map patron-stations
  { patron: principal }
  { station-ids: (list 50 uint) }
)

(define-map station-ratings
  { station-id: uint, rater: principal }
  { rating: uint, block-height: uint }
)

(define-map station-reputation
  { station-id: uint }
  { 
    total-rating: uint,
    rating-count: uint,
    average-rating: uint
  }
)

(define-map campaign-milestones
  { campaign-id: uint, milestone-index: uint }
  {
    target-percentage: uint,
    description: (string-ascii 128),
    is-claimed: bool,
    claimed-at: (optional uint)
  }
)

(define-map campaign-milestone-count
  { campaign-id: uint }
  { count: uint }
)

(define-read-only (get-station (station-id uint))
  (map-get? stations { station-id: station-id })
)

(define-read-only (get-subscription (patron principal) (station-id uint))
  (map-get? subscriptions { patron: patron, station-id: station-id })
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-matching-pool (campaign-id uint))
  (map-get? matching-pools { campaign-id: campaign-id })
)

(define-read-only (get-campaign-match-stats (campaign-id uint))
  (default-to { total-matched: u0 } (map-get? campaign-match-stats { campaign-id: campaign-id }))
)

(define-read-only (get-station-by-owner (owner principal))
  (match (map-get? station-owners { owner: owner })
    station-data (get-station (get station-id station-data))
    none
  )
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-min-subscription-amount)
  (var-get min-subscription-amount)
)

(define-read-only (get-patron-stations (patron principal))
  (default-to (list) (get station-ids (map-get? patron-stations { patron: patron })))
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (is-campaign-active (campaign-id uint))
  (match (get-campaign campaign-id)
    campaign-data
    (let ((current-block stacks-block-height))
      (and 
        (get is-active campaign-data)
        (>= current-block (get start-block campaign-data))
        (<= current-block (get end-block campaign-data))
      )
    )
    false
  )
)

(define-read-only (get-station-rating (station-id uint) (rater principal))
  (map-get? station-ratings { station-id: station-id, rater: rater })
)

(define-read-only (get-station-reputation (station-id uint))
  (default-to { total-rating: u0, rating-count: u0, average-rating: u0 } 
    (map-get? station-reputation { station-id: station-id }))
)

(define-read-only (get-station-average-rating (station-id uint))
  (get average-rating (get-station-reputation station-id))
)

(define-read-only (get-campaign-milestone (campaign-id uint) (milestone-index uint))
  (map-get? campaign-milestones { campaign-id: campaign-id, milestone-index: milestone-index })
)

(define-read-only (get-milestone-count (campaign-id uint))
  (default-to { count: u0 } (map-get? campaign-milestone-count { campaign-id: campaign-id }))
)

(define-read-only (calculate-milestone-target (campaign-id uint) (milestone-index uint))
  (match (get-campaign campaign-id)
    campaign-data
    (match (get-campaign-milestone campaign-id milestone-index)
      milestone-data
      (some (/ (* (get target-amount campaign-data) (get target-percentage milestone-data)) u100))
      none
    )
    none
  )
)

(define-public (register-station (name (string-ascii 64)) (description (string-ascii 256)) (location (string-ascii 64)))
  (let
    (
      (station-id (var-get next-station-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-none (map-get? station-owners { owner: tx-sender })) err-station-exists)
    (map-set stations
      { station-id: station-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        location: location,
        is-active: true,
        total-raised: u0,
        subscriber-count: u0,
        created-at: current-block
      }
    )
    (map-set station-owners { owner: tx-sender } { station-id: station-id })
    (var-set next-station-id (+ station-id u1))
    (ok station-id)
  )
)

(define-public (subscribe-to-station (station-id uint) (amount uint))
  (let
    (
      (station-data (unwrap! (get-station station-id) err-not-found))
      (current-block stacks-block-height)
      (platform-fee (calculate-platform-fee amount))
      (station-amount (- amount platform-fee))
      (existing-sub (get-subscription tx-sender station-id))
    )
    (asserts! (get is-active station-data) err-station-not-active)
    (asserts! (>= amount (var-get min-subscription-amount)) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match existing-sub
      existing-data
      (map-set subscriptions
        { patron: tx-sender, station-id: station-id }
        {
          amount: amount,
          created-at: (get created-at existing-data),
          last-payment: current-block,
          is-active: true
        }
      )
      (begin
        (map-set subscriptions
          { patron: tx-sender, station-id: station-id }
          {
            amount: amount,
            created-at: current-block,
            last-payment: current-block,
            is-active: true
          }
        )
        (map-set stations
          { station-id: station-id }
          (merge station-data { subscriber-count: (+ (get subscriber-count station-data) u1) })
        )
        (let ((current-stations (get-patron-stations tx-sender)))
          (map-set patron-stations
            { patron: tx-sender }
            { station-ids: (unwrap! (as-max-len? (append current-stations station-id) u50) err-invalid-amount) }
          )
        )
      )
    )
    
    (map-set stations
      { station-id: station-id }
      (merge station-data { total-raised: (+ (get total-raised station-data) station-amount) })
    )
    (ok true)
  )
)

(define-public (unsubscribe-from-station (station-id uint))
  (let
    (
      (subscription-data (unwrap! (get-subscription tx-sender station-id) err-not-found))
      (station-data (unwrap! (get-station station-id) err-not-found))
    )
    (asserts! (get is-active subscription-data) err-unauthorized)
    
    (map-set subscriptions
      { patron: tx-sender, station-id: station-id }
      (merge subscription-data { is-active: false })
    )
    
    (map-set stations
      { station-id: station-id }
      (merge station-data { subscriber-count: (- (get subscriber-count station-data) u1) })
    )
    (ok true)
  )
)

(define-public (create-campaign (station-id uint) (title (string-ascii 64)) (description (string-ascii 256)) (target-amount uint) (duration-blocks uint))
  (let
    (
      (station-data (unwrap! (get-station station-id) err-not-found))
      (campaign-id (var-get next-campaign-id))
      (current-block stacks-block-height)
      (end-block (+ current-block duration-blocks))
    )
    (asserts! (is-eq tx-sender (get owner station-data)) err-unauthorized)
    (asserts! (get is-active station-data) err-station-not-active)
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (> target-amount u0) err-invalid-amount)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        station-id: station-id,
        title: title,
        description: description,
        target-amount: target-amount,
        raised-amount: u0,
        start-block: current-block,
        end-block: end-block,
        is-active: true,
        creator: tx-sender
      }
    )
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (contribute-to-campaign (campaign-id uint) (amount uint))
  (let
    (
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (current-block stacks-block-height)
      (platform-fee (calculate-platform-fee amount))
      (contribution-amount (- amount platform-fee))
      (existing-contribution (map-get? campaign-contributions { campaign-id: campaign-id, contributor: tx-sender }))
      (pool (get-matching-pool campaign-id))
      (pool-active (and (is-some pool) (get active (unwrap-panic pool))))
      (pool-remaining (if pool-active (get remaining (unwrap-panic pool)) u0))
      (pool-rate (if pool-active (get rate (unwrap-panic pool)) u0))
      (raw-match (/ (* contribution-amount pool-rate) u10000))
      (match-amount (if pool-active (if (> raw-match pool-remaining) pool-remaining raw-match) u0))
    )
    (asserts! (is-campaign-active campaign-id) err-campaign-not-active)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match existing-contribution
      existing-data
      (map-set campaign-contributions
        { campaign-id: campaign-id, contributor: tx-sender }
        { amount: (+ (get amount existing-data) contribution-amount), block-height: current-block }
      )
      (map-set campaign-contributions
        { campaign-id: campaign-id, contributor: tx-sender }
        { amount: contribution-amount, block-height: current-block }
      )
    )
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign-data { raised-amount: (+ (get raised-amount campaign-data) contribution-amount match-amount) })
    )
    
    (if pool-active
      (begin
        (let ((pool-data (unwrap-panic pool)))
          (map-set matching-pools
            { campaign-id: campaign-id }
            (merge pool-data { remaining: (- (get remaining pool-data) match-amount) })
          )
        )
        (let ((stats (get-campaign-match-stats campaign-id)))
          (map-set campaign-match-stats
            { campaign-id: campaign-id }
            { total-matched: (+ (get total-matched stats) match-amount) }
          )
        )
        true
      )
      true
    )
    (ok true)
  )
)

(define-public (withdraw-station-funds (station-id uint) (amount uint))
  (let
    (
      (station-data (unwrap! (get-station station-id) err-not-found))
      (available-balance (get total-raised station-data))
    )
    (asserts! (is-eq tx-sender (get owner station-data)) err-unauthorized)
    (asserts! (>= available-balance amount) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (as-contract (stx-transfer? amount tx-sender (get owner station-data))))
    
    (map-set stations
      { station-id: station-id }
      (merge station-data { total-raised: (- available-balance amount) })
    )
    (ok true)
  )
)

(define-public (withdraw-campaign-funds (campaign-id uint))
  (let
    (
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (station-data (unwrap! (get-station (get station-id campaign-data)) err-not-found))
      (current-block stacks-block-height)
      (withdrawal-amount (get raised-amount campaign-data))
    )
    (asserts! (is-eq tx-sender (get creator campaign-data)) err-unauthorized)
    (asserts! (> current-block (get end-block campaign-data)) err-campaign-not-active)
    (asserts! (> withdrawal-amount u0) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get owner station-data))))
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign-data { raised-amount: u0, is-active: false })
    )
    (ok withdrawal-amount)
  )
)

(define-public (create-matching-pool (campaign-id uint) (rate uint) (cap uint))
  (let
    (
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (existing (get-matching-pool campaign-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get creator campaign-data)) err-unauthorized)
    (asserts! (is-campaign-active campaign-id) err-campaign-not-active)
    (asserts! (is-none existing) err-pool-exists)
    (asserts! (and (> rate u0) (<= rate u10000)) err-invalid-rate)
    (asserts! (> cap u0) err-invalid-amount)
    
    (try! (stx-transfer? cap tx-sender (as-contract tx-sender)))
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      { sponsor: tx-sender, rate: rate, cap: cap, remaining: cap, active: true, created-at: current-block }
    )
    (map-set campaign-match-stats { campaign-id: campaign-id } { total-matched: u0 })
    (ok true)
  )
)

(define-public (deactivate-matching-pool (campaign-id uint))
  (let
    (
      (pool (unwrap! (get-matching-pool campaign-id) err-pool-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor pool)) err-unauthorized)
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool { active: false })
    )
    (ok true)
  )
)

(define-public (refund-matching-pool (campaign-id uint))
  (let
    (
      (pool (unwrap! (get-matching-pool campaign-id) err-pool-not-found))
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (current-block stacks-block-height)
      (remaining (get remaining pool))
    )
    (asserts! (is-eq tx-sender (get sponsor pool)) err-unauthorized)
    (asserts! (or (not (get active pool)) (> current-block (get end-block campaign-data))) err-campaign-not-active)
    (asserts! (> remaining u0) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? remaining tx-sender (get sponsor pool))))
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool { remaining: u0, active: false })
    )
    (ok remaining)
  )
)

(define-public (update-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (update-min-subscription-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-amount u0) err-invalid-amount)
    (var-set min-subscription-amount new-amount)
    (ok true)
  )
)

(define-public (deactivate-station (station-id uint))
  (let
    (
      (station-data (unwrap! (get-station station-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner station-data)) err-unauthorized)
    
    (map-set stations
      { station-id: station-id }
      (merge station-data { is-active: false })
    )
    (ok true)
  )
)

(define-public (rate-station (station-id uint) (rating uint))
  (let
    (
      (station-data (unwrap! (get-station station-id) err-not-found))
      (current-block stacks-block-height)
      (existing-rating (get-station-rating station-id tx-sender))
      (current-reputation (get-station-reputation station-id))
      (current-total (get total-rating current-reputation))
      (current-count (get rating-count current-reputation))
    )
    (asserts! (get is-active station-data) err-station-not-active)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (is-none existing-rating) err-already-rated)
    
    (map-set station-ratings
      { station-id: station-id, rater: tx-sender }
      { rating: rating, block-height: current-block }
    )
    
    (let 
      (
        (new-total (+ current-total rating))
        (new-count (+ current-count u1))
        (new-average (/ (* new-total u100) new-count))
      )
      (map-set station-reputation
        { station-id: station-id }
        {
          total-rating: new-total,
          rating-count: new-count,
          average-rating: new-average
        }
      )
    )
    (ok true)
  )
)

(define-public (create-campaign-milestone (campaign-id uint) (target-percentage uint) (description (string-ascii 128)))
  (let
    (
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (milestone-count-data (get-milestone-count campaign-id))
      (current-count (get count milestone-count-data))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get creator campaign-data)) err-unauthorized)
    (asserts! (is-campaign-active campaign-id) err-campaign-not-active)
    (asserts! (and (> target-percentage u0) (<= target-percentage u100)) err-invalid-milestone)
    
    (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-index: current-count }
      {
        target-percentage: target-percentage,
        description: description,
        is-claimed: false,
        claimed-at: none
      }
    )
    
    (map-set campaign-milestone-count
      { campaign-id: campaign-id }
      { count: (+ current-count u1) }
    )
    (ok current-count)
  )
)

(define-public (claim-milestone-funds (campaign-id uint) (milestone-index uint))
  (let
    (
      (campaign-data (unwrap! (get-campaign campaign-id) err-not-found))
      (station-data (unwrap! (get-station (get station-id campaign-data)) err-not-found))
      (milestone-data (unwrap! (get-campaign-milestone campaign-id milestone-index) err-milestone-not-found))
      (milestone-target (unwrap! (calculate-milestone-target campaign-id milestone-index) err-milestone-not-found))
      (current-block stacks-block-height)
      (raised (get raised-amount campaign-data))
      (station-owner (get owner station-data))
    )
    (asserts! (is-eq tx-sender (get creator campaign-data)) err-unauthorized)
    (asserts! (not (get is-claimed milestone-data)) err-milestone-already-claimed)
    (asserts! (>= raised milestone-target) err-target-not-reached)
    
    (let
      (
        (withdrawal-amount (/ (* raised (get target-percentage milestone-data)) u100))
      )
      (try! (as-contract (stx-transfer? withdrawal-amount tx-sender station-owner)))
      
      (map-set campaign-milestones
        { campaign-id: campaign-id, milestone-index: milestone-index }
        (merge milestone-data { is-claimed: true, claimed-at: (some current-block) })
      )
      
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign-data { raised-amount: (- raised withdrawal-amount) })
      )
      (ok withdrawal-amount)
    )
  )
)
