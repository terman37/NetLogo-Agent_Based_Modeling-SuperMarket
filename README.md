# NetLogo - Agent based Modeling - SuperMarket

Netlogo model showing how the number of checkout station opened can influence the result of the store.

<img src="supermarket.gif" alt="supermarket" style="zoom:50%;" />

## WHAT IS IT?

The main idea of the model is to simulate a supermarket
and especially how the number of checkout station opened can influence the final result.
if many people are upset because of the queue at checkout, they leave the store without paying. 

## HOW IT WORKS

In the Setup phase, layout for the store is created:

- blue zone: entrance for new customers
- yellow zones: products (each patch is a different product)
- grey zone: queuing zone for checkout
- red patches: checkout stations (turn green when open)
- cyan patch: station to leave without product

When ready, then customers can enter the store...

Each customer:

- goes in the store with a defined shopping list	
- moves to the closest product
- pick it and add it to his cart
- goes to the following closest product
   ...
- until shopping list is over
- if he forgot something in his list, he can add it and go pick it
- moves towards the checkout stations
- select one opened checkout station following his strategy:
  - closest queue
  - queue with less customers
  - queue with less product in cart of waiting customers
  - randomly (he doesn't care)
- go to the selected queue
- if too many people in the queue he decides:
  - to leave the store without the cart (missed money for the store)
  - to select another one (if he still has some patience...)
  - when in the queue, he waits for his turn (each queue has a different speed...)
  - he pays the cart and leave the store

## HOW TO USE IT

The time scale to make the result more readable is 500 ticks = 1 hour

**nb-hours-before-stop**: nb of ticks ( /500 ) before to stop the simlation

**product-max-price**: maximum product price, price for products are given randomly between 1 and product-max-price + 1. Prices are defined during the setup. When simulation is running prices stay as thay are

**product-margin**: define how many money the store earned for each cart. it should be understood as the product margin including all store costs except the checkout costs, as it is our zone of interest.

**max-customer-number**: max number of customers allowed in the store.

**max-entrance-speed**: nb of customers that can be created at each tick, allow to manage customer flow. 

**max-length-shopping-list**: maxnumber of product that will be included in the customer shopping list

**max-prob-for-change**: maximum probability that customer has forgotten something in the list and will add it at the end.

**avg-checkout-speed**: each checkout station has a speed to take products from the cart. the speed is setup at checkout opening. If needed, if you increase/decrease the speed, you can renew cashiers and setup new checkout speed for all.

**customer-patience**: define the probability for the customer to select another checkout queue if too many people in the one he has selected. 

**checkout-cost-per-hour**: cost (per hour ~500 ticks) for each checkout station, this allow to penalize the result when too many checkout stations are opened.

**percent-checkout-open**: percentage of checkout station to open, when nb of opened checkout is decreasing, customers in the queue can still continue but no new one is allowed.

## THINGS TO NOTICE

I had no info regarding product prices, margins, checkout speed, checkout costs, so it may not be realistic or accurate. 
I made the model using my own experience as a supermarket customer... 

## THINGS TO TRY

It's a good exercise (almost a game) to fix the parameters and try to maximize the money earned by the store by just playing on the number of checkout stations opened/closed.

## EXTENDING THE MODEL

Model is quite easily extendable to match a real store (many more products, other layout), I think layout editor for the store could be easily implemented modifying a little bit the "Pac-Man Level Editor" in models library

Another thing that would make model more realistic would be to add stock management for each item. when customer pick one product, its stock decrease. then other agents coud be created to refill the products in the store.

## RELATED MODELS

I was inspired by some existing models (especially for moving customers in the store):
in Models Library:

- Look Ahead Example
- Move Towards Target Example
- Wall Following Example









