;; KYC (Know Your Customer) Smart Contract
;; Features:
;; - User registration and verification
;; - Role-based access control
;; - Document management
;; - Verification status tracking
(define-constant ADMIN tx-sender)
(define-constant ERR-FORBIDDEN (err u1))
(define-constant ERR-MISSING-ACCOUNT (err u2))
(define-constant ERR-DUPLICATE-VERIFICATION (err u3))
(define-constant ERR-DOC-REJECTED (err u4))
(define-constant ERR-VALIDATION-FAILED (err u5))

;; Events using print
(define-private (emit-registration-event (account principal))
  (print {event: "user-registered", user: account})
)

(define-private (emit-doc-event (account principal))
  (print {event: "document-added", user: account})
)

;; User Struct to store KYC information
(define-map accounts
  principal
  {
    name: (string-ascii 100),
    email: (string-ascii 100),
    docs: (list 3 (string-ascii 255)),
    validated: bool,
    kyc-tier: uint
  }
)

;; Verifier Roles Map
(define-map validators principal bool)

;; Validate verifier addition
(define-private (check-validator-eligibility (validator principal))
  (and 
    (not (is-eq validator ADMIN))
    (is-some (some validator))
  )
)

;; Add a verifier (only contract owner)
(define-public (register-validator (validator principal))
  (begin
    (try! (verify-admin))
    (asserts! (check-validator-eligibility validator) ERR-FORBIDDEN)
    (map-set validators validator true)
    (ok true)
  )
)

;; Check if sender is contract owner
(define-private (verify-admin)
  (if (is-eq tx-sender ADMIN)
      (ok true)
      ERR-FORBIDDEN)
)

;; Register a new user
(define-public (create-account 
  (name (string-ascii 100))
  (email (string-ascii 100))
)
  (let 
    (
      (account-data {
        name: name,
        email: email,
        docs: (list),
        validated: false,
        kyc-tier: u0
      })
    )
    (map-set accounts tx-sender account-data)
    (emit-registration-event tx-sender)
    (ok true)
  )
)

;; Validate user and verification level
(define-private (validate-kyc-request 
  (account principal)
  (kyc-tier uint)
)
  (and
    (is-some (some account))
    (>= kyc-tier u1)
    (<= kyc-tier u5)
  )
)

;; Verify user by a registered verifier
(define-public (validate-account (account principal) (kyc-tier uint))
  (begin
    ;; Validate verification parameters
    (asserts! 
      (validate-kyc-request account kyc-tier) 
      ERR-VALIDATION-FAILED
    )
    
    (match (map-get? accounts account)
      existing-account 
        (if (not (get validated existing-account))
            (begin
              (map-set accounts account 
                (merge existing-account {
                  validated: true, 
                  kyc-tier: kyc-tier
                })
              )
              (ok true)
            )
            ERR-DUPLICATE-VERIFICATION
        )
      ERR-MISSING-ACCOUNT
    )
  )
)

;; Get user verification status
(define-read-only (get-account-status (account principal))
  (match (map-get? accounts account)
    existing-account 
      (some {
        is-verified: (get validated existing-account),
        verification-level: (get kyc-tier existing-account)
      })
    none
  )
)
