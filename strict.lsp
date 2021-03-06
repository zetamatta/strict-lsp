
; (strict) の下請け関数
; S式の中から、未宣言の変数を検索する
;   vars - 宣言済み変数のリスト
;   s-exp - S式
; returns
;   ( 未宣言の変数のリスト 使用された変数のリスト)
(defun strictsub (vars s-exp / warnings word add-warn add-used test-var call-self eval-rest used)
  (setq warnings nil)
  (setq used nil)

  (defun add-used (x)
    (or (member x used)
        (setq used (cons x used))))

  (defun add-warn (x)
    (or (member x warnings)
        (setq warnings (cons x warnings))))

  (defun call-self (v x / r tmp)
    (setq r (strictsub v x))
    (foreach tmp (car r)
      (add-warn tmp))
    (foreach tmp (cadr r)
      (add-used tmp))
  )

  (defun eval-rest (a / tmp)
    (if (listp a)
      (foreach tmp a
        (if (listp tmp)
          (call-self vars tmp)))))

  (defun test-var (v)
    (if v
      (if (member v vars)
        (add-used v)
        (add-warn v)
      )
    )
  )

  (cond
    ((or (not s-exp) (not (listp s-exp)))
         ; do nothing
    )
    ((= (setq word (car s-exp)) 'QUOTE)
         ; do nothing
    )
    ((= word 'LAMBDA)
      (call-self (append vars (cadr s-exp)) (cddr s-exp))
    )
    ((= word 'DEFUN)
      (test-var (cadr s-exp))
      (call-self (append vars (caddr s-exp)) (cdddr s-exp))
    )
    ((= word 'FOREACH)
      (test-var (cadr s-exp))
      (eval-rest (cddr s-exp))
    )
    ((= word 'SETQ)
      ((lambda (/ equtions)
        (setq equtions (cdr s-exp))
        (while equtions
            (test-var (car equtions))

            (if (listp (cadr equtions))
              (call-self vars (cadr equtions))
            )

            (setq equtions (cddr equtions))
        )
      ))
    )
    (T
      (if (listp (car s-exp))
        (call-self vars (car s-exp))
      )
      (eval-rest (cdr s-exp))
    )
  )
  (list warnings used)
)

; Lisp のソースで定義されている関数内で、
; ローカル宣言されていない変数に setq / foreach していたら、
; 表示する
(defun strict (fname / tmp fd source s-exp r vars)
  ; 拡張子がなければ付加
  (if (or (< (strlen fname) 4)
          (/= (strcase (substr fname (- (strlen fname) 3))) ".LSP"))
    (setq fname (strcat fname ".lsp"))
  )
  (cond
    ; 検索パスからフルパス検索できなければエラー
    ((not (setq tmp (findfile fname)))
      (alert (strcat "can not find " fname))
    )
    ; ソースをロードできなければエラー
    ((not (setq fd (open tmp "r")))
      (alert (strcat "can not open " tmp))
    )
    (T
      ; read file all
      (setq source "(")
      (while (setq tmp (read-line fd))
        (setq source (if source (strcat source "\n" tmp) tmp))
      )
      (setq source (strcat source "\n)"))
      (close fd)
      (setq fd nil)

      ; to S-expression
      ((lambda (/ save-error)
        (setq save-error *error*)
        (defun *error* (msg)
          (setq msg nil)
          (terpri)
          (princ fname)
          (princ ": syntax error")
          (setq *error* save-error)
          (princ)
        )
        (setq s-exp (read source))
        (setq *error* save-error)
      ))

      (foreach tmp s-exp
        (if (= (car tmp) 'DEFUN)
          ((lambda ( / r funcname v)
            (setq funcname (cadr tmp))
            (setq r (strictsub (setq vars (caddr tmp)) (cdddr tmp)))

            (foreach v (car r)
              (if (/= v '*error*)
                (progn
                  (terpri)
                  (prin1 funcname)
                  (princ ": ")
                  (prin1 v)
                  (princ " has no declarations.")
                )
              )
            )
            (foreach v (cdr (member '/ vars))
              (if (not (member v (cadr r)))
                (progn
                  (terpri)
                  (prin1 funcname)
                  (princ ": ")
                  (prin1 v)
                  (princ " is unused.")
                )
              )
            ) ; foreach
          )) ; lambda
        ) ; if
      ) ; foreach
    ) ; T
  ) ; cond
  (if fd (close fd))
  (princ)
)
