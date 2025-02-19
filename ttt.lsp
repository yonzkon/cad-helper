(vl-load-com)

;; RegExpSet
;; Returns the current VBScript.RegExp instance after defining its properties.
;;
;; Arguments
;; pattern    : Pattern to search.
;; ignoreCase : If non nil, the search is done ignoring the case.
;; global     : If non nil, search all occurences of the pattern;
;;              if nil, only searches the first occurence.

(defun RegExpSet (pattern ignoreCase global / regex)
  (setq regex
        (cond ((vl-bb-ref '*regexp*))
              ((vl-bb-set '*regexp* (vlax-create-object "VBScript.RegExp")))))
  (vlax-put regex 'Pattern pattern)
  (if ignoreCase
      (vlax-put regex 'IgnoreCase acTrue)
    (vlax-put regex 'IgnoreCase acFalse))
  (if global
      (vlax-put regex 'Global acTrue)
    (vlax-put regex 'Global acFalse))
  regex)

;; RegexpTest
;; Return T if a match with the pattern is found in the string; otherwise, nil.
;;
;; Arguments
;; string     : String in which the pattern is searched.
;; pattern    : Pattern to search.
;; ignoreCase : If non nil, the search is done ignoring the case.
;;
;; Examples :
;; (RegexpTest "foo bar" "Ba" nil)  ; => nil
;; (RegexpTest "foo bar" "Ba" T)    ; => T
;; (RegExpTest "42C" "[0-9]+" nil)  ; => T

(defun RegexpTest (string pattern ignoreCase)
  (= (vlax-invoke (RegExpSet pattern ignoreCase nil) 'Test string) -1))

;; RegExpExecute
;; Returns the list of matches with the pattern found in the string.
;; Each match is returned as a sub-list containing:
;; - the match value
;; - the index of the first character (0 based)
;; - a list of sub-groups.
;;
;; Arguments
;; string     : String in which the pattern is searched.
;; pattern    : Pattern to search.
;; ignoreCase : If non nil, the search is done ignoring the case.
;; global     : If non nil, search all occurences of the pattern;
;;              if nil, only searches the first occurence.

;;
;; Examples
;; (RegExpExecute "foo bar baz" "ba" nil nil)               ; => (("ba" 4 nil))
;; (RegexpExecute "12B 4bis" "([0-9]+)([A-Z]+)" T T)        ; => (("12B" 0 ("12" "B")) ("4bis" 4 ("4" "bis")))
;; (RegexpExecute "-12 25.4" "(-?\\d+(?:\\.\\d+)?)" nil T)  ; => (("-12" 0 ("-12")) ("25.4" 4 ("25.4")))

(defun RegExpExecute (string pattern ignoreCase global / sublst lst)
  (vlax-for match (vlax-invoke (RegExpSet pattern ignoreCase global) 'Execute string)
            (setq sublst nil)
            (vl-catch-all-apply
             '(lambda ()
	              (vlax-for submatch (vlax-get match 'SubMatches)
	                        (if submatch (setq sublst (cons submatch sublst))))))
            (setq lst (cons (list (vlax-get match 'Value) (vlax-get match 'FirstIndex) (reverse sublst)) lst)))
  (reverse lst))

;; RegExpReplace
;; Returns the string after replacing matches with the pattern
;;
;; Arguments
;; string     : String in which the pattern is searched.
;; pattern    : Pattern to search.
;; newStr     : replacement string.
;; pattern    : Pattern to search.
;; ignoreCase : If non nil, the search is done ignoring the case.
;; global     : If non nil, search all occurences of the pattern;
;;              if nil, only searches the first occurence.
;;
;; Examples :
;; (RegexpReplace "foo bar baz" "a" "oo" nil T)                  ; => "foo boor booz"
;; (RegexpReplace "foo bar baz" "(\\w)\\w(\\w)" "$1_$2" nil T)   ; => "f_o b_r b_z"

(defun RegExpReplace (string pattern newStr ignoreCase global)
  (vlax-invoke (RegExpSet pattern ignoreCase global) 'Replace string newStr))

;; c:ttt of cad-helper

(defun x:nth-replace (newitem position alist / i)
  (setq i -1)
  (mapcar '(lambda (x) (if (= position (setq i (1+ i))) newitem x)) alist))

(defun x:split (str delim / ptr lst)
  (while (setq ptr (vl-string-search delim str))
    (setq lst (cons (substr str 1 ptr) lst))
    (setq str (substr str (+ ptr 2))))
  (reverse (cons str lst)))

(defun x:cat_devname (devname linum format_idx / regmat)
  (cond ((= format_idx 0)
         (setq regmat (RegExpExecute linum "^([0-9]A[0-9]+)\\+$" nil nil))
         (if regmat
             (progn (setq regmat (caar regmat))
                    (setq regmat (substr regmat 1 (- (strlen regmat) 1)))
                    (setq devname (strcat devname "P-" regmat)))
           (setq devname (x:cat_devname devname linum 1))))
        ((= format_idx 1)
         (setq regmat (RegExpExecute linum "^([0-9]AO[0-9])+\\+$" nil nil))
         (if regmat
             (progn (setq regmat (caar regmat))
                    (setq regmat (substr regmat 1 (- (strlen regmat) 1)))
                    (setq devname (strcat devname "P-" regmat)))
           (setq devname (x:cat_devname devname linum 2))))
        ((= format_idx 2)
         (setq regmat (RegExpExecute linum "^E[0-9]+\\.[0-9]+$" nil nil))
         (if regmat
             (progn (setq regmat (caar regmat))
                    (setq devname (strcat devname "P-" regmat)))
           (setq devname (x:cat_devname devname linum 3))))
        ((= format_idx 3)
         (setq regmat (RegExpExecute linum "^([0-9])+-[0-9]+$" nil nil))
         (if regmat
             (progn (setq regmat (caar regmat))
                    (setq regmat (substr regmat 1 (vl-string-search "-" regmat)))
                    (setq devname (strcat devname "P-KA" regmat)))
           (setq devname nil))))
  devname)

(defun x:process-content (items devices / devname regmat ptr linum)
  (setq devname (nth 6 items))
  (setq regmat (RegExpExecute devname "(DCS[0-9]+)" nil nil))
  (if (not regmat)
      (progn (princ "\nnot avialable devname: ")
             (princ devname)
             (princ items))
    (progn (if (= "DCS0" (substr (caar regmat) 1 4))
               (setq devname (substr (caar regmat) 5))
             (setq devname (substr (caar regmat) 4)))

           (setq linum (nth 10 items))

           ;(print (RegexpExecute "12B 4bis" "([0-9]+)([A-Z]+)" T T))
           ;(vl-exit-with-value 1)

           ; FIXME is there "return" in lisp????????
           (setq devname (x:cat_devname devname linum 0))

           ; process replacement
           (if devname
               (progn (princ "\nadd device: ")
                      (princ devname)
                      (setq devices (cons (cons devname items) devices))))
           ))
  devices)

(defun x:process-replace (ss devices / attrname devname device items ssidx next ed)
  (setq ssidx 0)
  (while (/= ssidx (sslength ss))
    (setq next (ssname ss ssidx))
    (setq next (entnext next))
    (setq attrname (cdr (assoc 2 (entget next))))
    (setq devname (cdr (assoc 1 (entget next))))
    (if (or (not devname) (/= attrname "机柜地址"))
        (progn (princ "\nnot avaiable entity, attrname: ")
               (princ attrname))
      (progn (setq device (assoc devname devices))
             (if (not device)
                 (progn (princ "\nnot find entity, attrname: ")
                        (princ attrname)
                        (princ ", devname: ")
                        (princ devname))
               (progn (setq items (x:split (nth 13 device) "^"))
                      (if (/= (length items) 3)
                          (progn (princ "\nwrong format of column 'CAD': ")
                                 (princ items)
                                 (princ device)
                                 (princ "\nexit ...")
                                 (vl-exit-with-value 1)))

                      ; system address
                      (setq next (entnext next))

                      ; usage
                      (setq next (entnext next))
                      (setq ed (entget next))
                      (setq ed (subst (cons 1 (nth 2 items)) (assoc 1 ed) ed))
                      (entmod ed)

                      ; meter tag
                      (setq next (entnext next))
                      (setq ed (entget next))
                      (setq ed (subst (cons 1 (nth 1 items)) (assoc 1 ed) ed))
                      (entmod ed)

                      ; device name
                      (setq next (entnext next))
                      (setq ed (entget next))
                      (setq ed (subst (cons 1 (nth 0 items)) (assoc 1 ed) ed))
                      (entmod ed)))))

    (setq ssidx (1+ ssidx))))

(defun c:ttt (/ fname fp line items last-dev-items devices ss)
  ; get finename
  (setq fname (getenv "ttt-last-fname"))
  (if (not fname) (setq fname ""))
  (setq fname (getfiled "" fname "txt" 8))
  (cond ((not fname)
         (print "not specifiy filename, exit ...")
         (vl-exit-with-error "")))
  (setenv "ttt-last-fname" fname)

  ; open file
  (setq fp (open fname "r"))

  ; skip header lines, FIXME: not check if line is nil
  (setq line (read-line fp))
  (setq items (x:split line "\t"))
  (while (and line (/= (nth 0 items) "1"))
    (setq line (read-line fp))
    (setq items (x:split line "\t")))

  ; process content lines
  (while line
    (setq items (x:split line "\t"))
    (if (/= (nth 0 items) "")
        (setq last-dev-items items)
      (progn (setq items (x:nth-replace (nth 0 last-dev-items) 0 items))
             (setq items (x:nth-replace (nth 1 last-dev-items) 1 items))
             (setq items (x:nth-replace (nth 2 last-dev-items) 2 items))
             (setq items (x:nth-replace (nth 3 last-dev-items) 3 items))
             (setq items (x:nth-replace (nth 4 last-dev-items) 4 items))
             (setq items (x:nth-replace (nth 5 last-dev-items) 5 items))
             (setq items (x:nth-replace (nth 6 last-dev-items) 6 items))
             (setq items (x:nth-replace (nth 7 last-dev-items) 7 items))
             ))
    (setq devices (x:process-content items devices))
    (setq line (read-line fp)))

  ; close file
  (close fp)

  ; process replace
  (setq ss (ssget "X" '((0 . "INSERT") (2 . "IO点位注释"))))
  (if ss (x:process-replace ss devices))
  (setq ss (ssget "X" '((0 . "INSERT") (2 . "AI点位注释"))))
  (if ss (x:process-replace ss devices))
  (setq ss (ssget "X" '((0 . "INSERT") (2 . "AO点位注释"))))
  (if ss (x:process-replace ss devices))
  (setq ss (ssget "X" '((0 . "INSERT") (2 . "DI点位注释"))))
  (if ss (x:process-replace ss devices))
  (setq ss (ssget "X" '((0 . "INSERT") (2 . "DO点位注释"))))
  (if ss (x:process-replace ss devices))

  (princ))
