;;;; Draw the nine rooms on the screen
;;;; @(#)rooms.c	3.8 (Berkeley) 6/15/81

(in-package :cl-rogue)

(defun do-rooms()
  ;; bsze is the maximum room size
  ;; TODO: I'm limiting to 80x24 here because I'm not sure
  ;; if this code works at bigger sizes.
  (let*
      ((max-cols (min 80 cl-ncurses:*cols*))
       (max-lines (min 24 cl-ncurses:*lines*))
       (bsze (make-coord :x (truncate (/ max-cols
                                         3))
                         :y (truncate (/  max-lines
                                          3)))))
    ;; Clear things for a new level
    (map nil
         #'(lambda (rp)
             (zero! (moor-r-goldval rp)
                    (moor-r-nexits rp)
                    (moor-r-flags rp)))
         rooms)
    ;; Put the gone rooms, if any, on the level
    (loop repeat (rnd 4)
       do (logior! (moor-r-flags (aref rooms (rnd-room)))
                   ISGONE))
    ;; Dig and populate all the rooms on the level
    (dotimes (i MAXROOMS)
      (block :continue
        (let ((rp (aref rooms i))
              (top (make-coord :x (1+ (* (mod i 3)
                                         (coord-x bsze)))
                               :y (* (truncate (/ i 3))
                                     (coord-y bsze)))))
          ;; Find upper left corner of box that this room goes in.
          (when (logtest (moor-r-flags rp) ISGONE)
            ;; Place a gone room.  Make certain that there is a
            ;; blank line for passage drawing.
            (loop
               (setf
                (coord-x (moor-r-pos rp)) (+ (coord-x top) 
                                             (rnd (- (coord-x bsze) 
                                                     2))
                                             1)
                (coord-y (moor-r-pos rp)) (+ (coord-y top) 
                                             (rnd (- (coord-y bsze) 
                                                     2))
                                             1)
                (coord-x (moor-r-max rp)) (- max-cols)
                (coord-y (moor-r-max rp)) (- max-lines))
               (when (and (plusp (coord-y (moor-r-pos rp)))
                          (< (coord-y (moor-r-pos rp))
                             (1- max-lines)))
                 (return)))
            (return-from :continue))

          (when (< (rnd 10) (1- level))
            (logior! (moor-r-flags rp) ISDARK))

          ;; Find a place and size for a random room
          (loop
             (setf
              (coord-x (moor-r-max rp)) (+ (rnd (- (coord-x bsze) 4)) 
                                           4)
              (coord-y (moor-r-max rp)) (+ (rnd (- (coord-y bsze) 4)) 
                                           4)
              (coord-x (moor-r-pos rp)) (+ (coord-x top) 
                                           (rnd (- (coord-x bsze) 
                                                   (coord-x (moor-r-max rp)))))
              (coord-y (moor-r-pos rp)) (+ (coord-y top) 
                                           (rnd (- (coord-y bsze) 
                                                   (coord-y (moor-r-max rp))))))
             (unless (zerop (coord-y (moor-r-pos rp)))
               (return)))

          ;; Put the gold in
          (when (and (< (rnd 100) 50)
                     (or (not *amulet*)
                         (>= level max-level)))
            (setf (moor-r-goldval rp) (goldcalc))
            (rnd-pos rp (moor-r-gold rp))
            (when (not (eq (roomin (moor-r-gold rp)) rp))
              (rogue-done)))
          (draw-room rp)
          ;; Put the monster in
          (when (< (rnd 100) 
                   (if (plusp (moor-r-goldval rp)) 80 25))
            (let ((tp (make-thing))
                  (mp (make-coord)))
              (loop
                 (rnd-pos rp mp)
                 (when (eq (rogue-mvwinch cl-ncurses:*stdscr*
                                          (coord-y mp)
                                          (coord-x mp))
                           FLOOR)
                   (return)))
              (new-monster tp (randmonster nil) mp)

              ;; See if we want to give it a treasure to carry around.
              (when (< (rnd 100) 
                       (monster-m-carry (char-monster (thing-t-type tp))))
                (attach (thing-t-pack tp) (new-thing))))))))))

(defun rpy (rp)
  (coord-y (moor-r-pos rp)))

(defun rpx (rp)
  (coord-x (moor-r-pos rp)))

(defun rmy (rp)
  (coord-y (moor-r-max rp)))

(defun rmx (rp)
  (coord-x (moor-r-max rp)))


(defun draw-room (rp)
  "Draw a box around a room."
  (let ((py (rpy rp))
        (px (rpx rp))
        (my (rmy rp))
        (mx (rmx rp)))
    (cl-ncurses:move py 
                     (1+ px))
    (vert (- my 2))                     ; Draw left side
    (cl-ncurses:move (1- (+ py my)) 
                     px)
    (horiz mx)                          ; Draw bottom
    (cl-ncurses:move py px)
    (horiz mx)                          ; Draw top
    (vert (- my 2))                     ; Draw right side
    ;; Put the floor down
    (do ((j 1 (1+ j)))
        ((>= j (1- my)))
      (cl-ncurses:move (+ py j) (1+ px))
      (do ((k 1 (1+ k)))
          ((>= k (1- mx)))
        (rogue-addch FLOOR)))
    ;; Put the gold there
    (when (plusp (moor-r-goldval rp))
      (rogue-mvaddch (coord-y (moor-r-gold rp))
                     (coord-x (moor-r-gold rp))
                     GOLD))))

(defun horiz (cnt)
  "Draw a horizontal line."
  (dotimes (_ cnt)
    (rogue-addch #\-)))

(defun vert (cnt)
  "Draw a vertical line."
  (let (x y)
    (cl-ncurses:getyx cl-ncurses:*stdscr* y x)
    (decf x)
    (dotimes (_ cnt)
      (cl-ncurses:move (incf y) x)
      (rogue-addch #\|))))

(defun rnd-pos (rp cp)
  "Pick a random spot in a room."
  (setf
   (coord-x cp) (+ (coord-x (moor-r-pos rp))
                   (rnd (- (coord-x (moor-r-max rp))
                           2))
                   1)
   (coord-y cp) (+ (coord-y (moor-r-pos rp))
                   (rnd (- (coord-y (moor-r-max rp))
                           2))
                   1)))

