;;;; mostly for clisp right now

#|
(defun load-user-init-file ()
  "Load the user init file, return NIL if it does not exist."
  (load (merge-pathnames (user-homedir-pathname)
                         (make-pathname :name ".clisprc" :type "lisp"))
        :if-does-not-exist nil))
;(load-user-init-file)

(unless (find-package :ql)
  (load-user-init-file))
|#

(ql:quickload "cl-json")
;;(ql:quickload "cl-fad")
(declaim (optimize (debug 3) (safety 3) (speed 0) (space 0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; finger




(defun run-finger (user)
  (run-program "finger" 
               :arguments (list user) :output :stream :wait t))

(defun finger (user)
  "Call the external finger program on USER, and return its result"
  (with-open-stream (stream (run-finger user))
    (loop :for line = (read-line stream nil nil)
       :while line :collect line)))

(defun plan-lines (finger-lines)
  "Given a list of lines returned by finger, , extract the lines after the plan"
  (cdr (member "Plan:" finger-lines :test #'equalp)))


(defun finger-to-plan (user)
  "Given a user-name, finger him, and convert the output to lines of a plan"
  (plan-lines (finger user)))

(defun lines-to-string (lines)
  "Convert a list of strings to a single string, separated by newlines"
  (format nil "~{~A~%~}" lines))

(defun finger-to-json (user)
  "Finger a user, returning his plan as a json structure"
  (let* ((lines (finger-to-plan user))
         (string (lines-to-string lines)))
    (handler-case
     (json:decode-json-from-string string)
     (error (e)
            (format t "Problem with ~a. Ignoring" user)
            nil))))

;(setf json (finger-to-json "dk@telekommunisten.org"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; utility functions


(defun cat$ (&rest args)
  (format nil "~{~a~}" args))

(defun slurp-file (filename)
  (with-open-file (stream  filename :direction :input)
                  (let ((seq (make-string (file-length stream))))
                    (read-sequence seq stream)
                    seq)))

(when (and (featurep :win32) (featurep :clisp))
  ;(defun home () (cat$ (getenv "USERPROFILE") "\\.plan"))  ; try user-homedir-pathname instead
  (defun username () (getenv "USERNAME"))
  (defun domain () (getenv "USERDOMAIN"))
  t)

(when (and (featurep :unix) (featurep :clisp))
  (defun username () (getenv "USERNAME"))
  (defun domain () (getenv "HOSTNAME"))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; my plan

(defvar *plan-filename* 
  (merge-pathnames (user-homedir-pathname)
                   (make-pathname :name ".plan" )))

(defvar *me* nil)

(defun setup (address bio name website mobile email)
  (setf *me* `((:bio . ,bio) 
               (:name . ,name)
               (:messages )
               (:replies )
               (:following )
               (:properties (:website . ,website)
                            (:mobile . ,mobile)
                            (:email . ,email)))))



(if (probe-file *plan-filename*)
    (setf *me* (json:decode-json-from-string (slurp-file *plan-filename*)))
  (setup (cat$ (username) "@" (domain)) ;address
                  "No bio" ; bio
                  (username) ; name
                  (cat$ "http://" (domain)) ; website
                  "Mobile witheld" ;mobile
                  (cat$ (username) "@" (domain)) ;email
                  ))

                      


(defun now-as-int ()
  "Return the time now as an integer"
  (loop for i from 0 to 5
        for v in (multiple-value-list (get-decoded-time))
        summing (* (expt 100 i) v)))

(defmacro cassoc (field-name branch)
  "A sub-association of a branch"
  `(cdr (assoc ,field-name ,branch)))

(defmacro plan-address (plan)
  "The address of a plan"
  `(cassoc :address ,plan))

(defmacro plan-messages (plan)
  "The messages associated with a plan"
  `(cassoc :messages ,plan))

(defmacro message-address (message)
   `(cassoc :address ,message))

(defmacro message-text (message)
   `(cassoc :text ,message))

(defmacro message-time (message)
  `(cassoc :time ,message))

(defun get-message-time (message)
  (message-time message))

(defun post (message)
  (push `((:text . ,message) (:time . ,(now-as-int))) 
        (cassoc :messages *me*)))

;  (setf (messages *me*) foo)

;;(post "hello world anew")

;;(post "using another macro")



(defun follow (nick address)
  "Follow someone"
  ;; FIXME SORT OUT CASE SAME ADDRESS, DIFFERENT NICK
  (pushnew `((:nick . ,nick) (:address . ,address)) 
           (cassoc :following *me*) 
           :test #'equalp))


;;(follow  "dk"     "dmytri@thimbl.tk")


(defun who-do-i-follow ()
  (loop for f in (cassoc :following *me*)
        collect (cassoc :address f)))

;;(who-do-i-follow)

(defvar *plans* nil)

(defun fetch ()
  (format t "Fetching plans ...~%")
  (setf *plans* (loop for f in (who-do-i-follow) 
                      for p = (finger-to-json f)
                      if p collect p))
  (format t "Plans fetched~%")
  t)

;(fetch)

;; bits below untested

(defun int (v)
  "Convert a value into an integer"
  (if (stringp v)
      (parse-integer v)
    v))

(defun unroll-messages (list-of-plans)
  "Return the messages of a list of plan, augmented by the plan address"
  (loop for p in list-of-plans
        for a = (plan-address p)
        append (loop for m in (plan-messages p)
                     do (setf (message-time m) (int (message-time m)))
                     collect (acons :address a m))))

;(unroll-messages *plans*)



(defun prim ()
  "Print all messages"
  (let* ((plans (append (list *me*) *plans*))
         ;(t1 (break))
         (unsorted-messages (unroll-messages plans))
         ;(t1 (print unsorted-messages))
	 (sorted-messages (sort unsorted-messages #'< 
                                :key #'get-message-time)))

    (loop for msg in sorted-messages do
	  (format t "~a   ~a ~%~a~%~%" 
                  (message-time msg) 
                  (message-address msg) 
                  (message-text msg)))))
(prim)
    

	

                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; (saveinitmem)
(defun rl () (load "thimbl.lisp")) ; a reloading function
