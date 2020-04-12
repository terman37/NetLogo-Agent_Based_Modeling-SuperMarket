;** global variables ********************

globals [product-counter nb-cust-out-tot nb-cust-no-pay money-earned money-missed]

patches-own [ product-price product-id checkout-speed]

breed [customers customer]
customers-own [shopping-list nb-product-in-cart cart-value selected-strategy prob-for-change next-destination nb-moves checkout-selected checkout-time direction]

;** setup *******************************

to setup
  clear-all
  init-globals
  setup-store-layout
  reset-ticks
end

to init-globals
  set product-counter 0
  set nb-cust-out-tot 0
  set nb-cust-no-pay 0
  set money-earned 0
  set money-missed 0
end

to setup-store-layout
  ; default background
  ask patches [set pcolor black ]
  ; entrance zone
  ask patches with [pxcor > 0 and pycor < 0 ] [ set pcolor blue ]
  ; checkout zone
  ask patches with [pxcor <= 0 and pycor < 0 ] [ set pcolor grey ]
  ; checkout stations (all closed)
  ask patches with [pxcor < 0 and pycor = -6 ] [ set pcolor red ]
  ; leave with no product
  ask patch 0 -6 [ set pcolor cyan ]
  ; create product places
  ask patches with [pycor > 0 and member? ( pxcor mod 4 )  [2 3 ] and not member? ( pycor mod 12 )  [0 1] ]
    [ set pcolor yellow
      set product-price random product-max-price
      set product-id product-counter
      set product-counter product-counter + 1
    ]
end

;** run *********************************
to go
  if ticks >= nb-hours-before-stop * 500 [ stop ]
  add-customer
  move-customer
  open-close-checkouts

  tick
end

to replace-cashiers
  ask patches with [ pcolor = green ][
    let speed avg-checkout-speed - 0.5 + random-float 1
    set checkout-speed speed
  ]
end

; open or close checkout stations
to open-close-checkouts
  let tot-checkouts count patches with [pcolor = red or pcolor = green or pcolor = orange]
  let step-size 1 / tot-checkouts * 100
  if count patches with [pcolor = green] / tot-checkouts * 100 < percent-checkout-open [
    ask one-of patches with [pcolor = red or pcolor = orange] [
      set pcolor green
      ;let speed ((random-float max-checkout-speed) + .5)
      let speed avg-checkout-speed - 0.5 + random-float 1
      set checkout-speed speed
    ]
  ]
  if count patches with [pcolor = green] / tot-checkouts * 100 - step-size > percent-checkout-open [
    ask one-of patches with [pcolor = green] [ set pcolor orange]
  ]
  ; if queue length = 0 then turn it red
  ask patches with [pcolor = orange] [
   let xc pxcor
   if count customers with [checkout-selected = xc] = 0 [
      set pcolor red
    ]
  ]
end

; move each customer
to move-customer
  ask customers [
    enter-the-store
    move-to-product
    pick-product
    move-to-checkout
    select-checkout
    enter-checkout-queue
    move-in-the-queue
    leave-without-paying
    pay-and-leave
    ; increase moves
    set nb-moves nb-moves + 1
  ]
end

; move out of entrance area
to enter-the-store
  ; go out of entrance zone (vertical move)
  if pcolor = blue [
    facexy xcor 0
    fd 1
  ]
end

; move to product and avoid obstacles
to move-to-product
  ; go to next product - in store move
  let dest next-destination
  if pcolor = black and not empty? shopping-list [
    ; direction next product
    face one-of patches with [product-id = dest]
    ; avoid obstacle
    ifelse [pcolor] of patch-ahead 1 != black [
      ; define direction to avoid obstacle
      ; find if product is above or below
      if direction = "None" [
        ifelse ycor < [pycor] of one-of patches with [product-id = dest] [
          set direction "cw"
        ][
          set direction "ccw"
        ]
      ]
      let angle 0
      while [wall? angle direction] [set angle angle + 1]
      ifelse direction = "ccw" [rt angle] [lt angle]
      fd 1
    ] [
      set direction "None"
      rt 0
      fd 1
    ]
  ]
end

; pick a product, remove it from the shopping list and define next
to pick-product
  if not empty? shopping-list [
    ; if destination reached -> remove product from list
    let dest next-destination
    if distance one-of patches with [product-id = dest] < 1 [
      set nb-product-in-cart nb-product-in-cart + 1
      set cart-value cart-value + [product-price] of one-of patches with [product-id = dest]
      set shopping-list remove next-destination shopping-list
      find-next-product
      set direction "None"
      ; nothing anymore to shop
      if empty? shopping-list [
        ; forgotten product - last minute addition
        ifelse random 100 < max-prob-for-change [
          let selected-product (random (product-counter - 1)) + 1
          set shopping-list lput selected-product shopping-list
          set next-destination selected-product
        ][
          set color green
        ]
      ]
    ]
  ]
end

; select checkout
to select-checkout
  if color = green and ycor < 1 [
    if selected-strategy = 0 [
      ; random strategy
      if checkout-selected = "None" [
        set checkout-selected [pxcor] of one-of patches with [pcolor = green]
      ]
    ]
    if selected-strategy = 1 [
      ; closest checkout strategy
      let min-dist 9999
      let selection 0
      ask patches with [pcolor = green] [
        let dist distance myself
        if dist < min-dist [
          set min-dist dist
          set selection pxcor
        ]
      ]
      set checkout-selected selection
    ]
    if selected-strategy = 2 [
      ; less article startegy
      let min-nb 9999
      let selection 0
      ask patches with [pcolor = green] [
        let nb 0
        ask customers with [checkout-selected = pxcor] [set nb nb + nb-product-in-cart]
        if nb < min-nb [
          set min-nb nb
          set selection pxcor
        ]
      ]
      set checkout-selected selection
    ]
    if selected-strategy = 3 [
      ; less crowded stategy
      let min-cust 9999
      let selection 0
      ask patches with [pcolor = green] [
        let nb 9999
        let x pxcor
        set nb count customers with [checkout-selected = x]
        if nb < min-cust [
          set min-cust nb
          set selection pxcor
        ]
      ]
      set checkout-selected selection
    ]
    set color orange
  ]
end

; move to checkout avoiding obstacles
to move-to-checkout
  ; go to next product - in store move
  if color = green or color = orange [
    ; direction next product
    ifelse color = green [
      facexy xcor 0
    ][
     facexy checkout-selected 0
    ]
    ; avoid obstacle
    ifelse [pcolor] of patch-ahead 1 != black [
      ; define direction to avoid obstacle
      ; find if product is above or below
      if direction = "None" [
        ifelse random 1 < 1 [
          set direction "cw"
        ][
          set direction "ccw"
        ]
      ]
      let angle 0
      while [wall? angle direction] [set angle angle + 1]
      ifelse direction = "ccw" [rt angle] [lt angle]
      fd 1
    ] [
      set direction "None"
      rt 0
      fd 1
    ]
  ]
end

; enter the queue
to enter-checkout-queue
  if color = orange and distance patch checkout-selected 0 < 1 [
    ; if queue is full then leave the store (maybe add probability to select another one ?)
    ifelse any? customers-on patch checkout-selected -1 [
      ifelse random 100 < customer-patience [
        set color green
        set checkout-selected "None"
        set selected-strategy 2
      ] [
        set checkout-selected 0
      ]
    ][
      setxy checkout-selected -1
      set color blue
      set checkout-time 1
    ]
  ]
end

; move in the queue
to move-in-the-queue
  if color = blue [
    ;show who
    ;show any? customers-on patch-at 0 -1
    ;show count turtles-at 0 -1
    if count customers-at 0 -1 = 0 [
      if pcolor != green and pcolor != orange and pcolor != cyan[
        setxy xcor (ycor - 1)
      ]
    ]
  ]
end

; upset clients leaving the store without paying
to leave-without-paying
  if pcolor = cyan [
    set nb-cust-out-tot nb-cust-out-tot + 1
    set nb-cust-no-pay nb-cust-no-pay + 1
    set money-missed money-missed + cart-value
    die
  ]
end

; checkout process
to pay-and-leave
  if pcolor = green or pcolor = orange [
    set nb-product-in-cart nb-product-in-cart - checkout-speed
    if nb-product-in-cart <= 0 [
      set nb-cust-out-tot nb-cust-out-tot + 1
      set money-earned money-earned + cart-value
      die
    ]
  ]
end

; avoid the walls
to-report wall? [angle direct]
  ifelse direct = "ccw" [
    report black != [pcolor] of patch-right-and-ahead angle 1
  ] [
    report black != [pcolor] of patch-left-and-ahead angle 1
  ]
end

; let new customers enter the store
to add-customer
  if count customers < max-customer-number
  [
    create-customers random max-entrance-speed [
      ; initializing new customer
      ;setxy random-xcor random-ycor
      ;move-to one-of patches with [pcolor = blue]
      set shape "person"
      set color white
      define-shopping-list
      set nb-product-in-cart 0
      set cart-value 0
      set selected-strategy random 3 ; strategies from 0 to 3
      set prob-for-change random max-prob-for-change
      find-next-product
      set checkout-selected "None"
      set nb-moves 0
      set checkout-time 0
      set direction "None"
      setxy one-of [pxcor] of patches with [pcolor = blue] one-of [pycor] of patches with [pcolor = blue]
    ]
  ]
end

; create the shopping list
to define-shopping-list
  set shopping-list []
  let i 0
  let length-shopping-list (random (max-length-shopping-list - 1)) + 1
  loop [
    if i = length-shopping-list
    [
      stop
    ]
    ;let selected-product (random product-counter - 1)
    let selected-product (random (product-counter - 1)) + 1
    if not member? selected-product shopping-list
    [
      set shopping-list lput selected-product shopping-list
    ]
    set i i + 1
  ]
end

; find the closest product in the store from the shopping list
to find-next-product
  let prev-dist 9999
  let prod-next 9999
  foreach shopping-list [id -> if dist-cust-to-prod id < prev-dist [set prod-next id set prev-dist dist-cust-to-prod id] ]
  set next-destination prod-next
  ;show prod-next
  ;foreach shopping-list [id -> ask patches with [product-id = id] [set pcolor orange] ]
  ;ask patches with [product-id = prod-next] [set pcolor pink set plabel "N"]
end

; measure distance from customer to product
to-report dist-cust-to-prod [ id ]
  let dist 99999
  ask patches with [product-id = id] [set dist distance myself]
  report dist
end
@#$#@#$#@
GRAPHICS-WINDOW
330
60
788
534
-1
-1
15.0
1
10
1
1
1
0
0
0
1
-24
5
-6
24
1
1
1
ticks
30.0

BUTTON
25
15
90
48
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
100
15
165
48
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
565
10
715
55
# products ref in store
count patches with [pcolor = yellow]
17
1
11

MONITOR
360
540
510
585
# checkout stations closed
count patches with [pcolor = red or pcolor = orange]
17
1
11

SLIDER
25
120
220
153
product-max-price
product-max-price
1
50
15.0
1
1
$
HORIZONTAL

SLIDER
25
160
220
193
max-customer-number
max-customer-number
1
1000
200.0
1
1
NIL
HORIZONTAL

SLIDER
25
305
220
338
max-prob-for-change
max-prob-for-change
0
99
10.0
1
1
%
HORIZONTAL

SLIDER
25
265
219
298
max-length-shopping-list
max-length-shopping-list
1
100
30.0
1
1
NIL
HORIZONTAL

BUTTON
175
15
240
48
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
795
155
1010
305
avg cart value
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"cart-value" 1.0 0 -3844592 true "" "plot mean [cart-value] of customers"

PLOT
795
310
1010
450
avg nb item in cart
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13840069 true "" "plot mean [nb-product-in-cart] of customers"

BUTTON
250
15
315
48
NIL
pen-down
NIL
1
T
TURTLE
NIL
NIL
NIL
NIL
1

SLIDER
25
375
220
408
percent-checkout-open
percent-checkout-open
1
100
39.0
1
1
%
HORIZONTAL

SLIDER
25
455
220
488
customer-patience
customer-patience
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
25
105
250
131
Max product price: calibrate to avg cart value
11
0.0
1

TEXTBOX
30
250
180
268
Shopping list:
11
0.0
1

TEXTBOX
30
360
180
378
Checkout:
11
0.0
1

MONITOR
1275
20
1470
65
$ missed
money-missed
17
1
11

MONITOR
1065
20
1260
65
$ earned
money-earned
17
1
11

MONITOR
1065
70
1260
115
# customers out
nb-cust-out-tot
17
1
11

MONITOR
1275
70
1470
115
# customers not paying
nb-cust-no-pay
17
1
11

PLOT
1280
440
1475
590
% customer leaving without paying
NIL
NIL
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot nb-cust-no-pay / nb-cust-out-tot * 100"

PLOT
1280
295
1475
435
# customers in store
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13791810 true "" "plot count customers"

SLIDER
25
415
220
448
avg-checkout-speed
avg-checkout-speed
0.1
3
2.0
.1
1
NIL
HORIZONTAL

MONITOR
515
540
665
585
# checkout stations opened
count patches with [pcolor = green]
17
1
11

SLIDER
25
200
220
233
max-entrance-speed
max-entrance-speed
0
20
5.0
1
1
NIL
HORIZONTAL

BUTTON
225
415
320
448
NIL
replace-cashiers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
795
455
1010
595
time spent in store (minutes)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (mean [nb-moves] of customers) / 500 * 60"

TEXTBOX
335
40
485
58
Time Scale 500 ticks = 1 hour
11
0.0
1

SLIDER
25
55
220
88
nb-hours-before-stop
nb-hours-before-stop
2
50
2.0
1
1
NIL
HORIZONTAL

SLIDER
25
495
220
528
checkout-cost-per-hour
checkout-cost-per-hour
5
50
10.0
1
1
$
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
