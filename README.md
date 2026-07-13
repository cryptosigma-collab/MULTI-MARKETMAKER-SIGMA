# MULTI-MARKETMAKER-SIGMA
A multi-level market making trading engine written in Python for Kraken.
MULTI-MARKETMAKER-SIGMA
Core Strategy Rules
1. Strategy Purpose
MULTI-MARKETMAKER-SIGMA is a stateful multi-level market-making strategy.
The strategy continuously maintains multiple working ENTER orders below the current market while managing each filled ENTER as an independent position with its own matching EXIT order.
Each filled level temporarily owns a surrounding price range. That range cannot be reused until the matching EXIT order is completely filled.

2. User Inputs
Asset
The asset being traded.
Example:
BTC
Levels
The number of working ENTER orders the strategy should maintain.
Example:
Levels = 10
The strategy should normally maintain:
10 ENTER_OPEN orders
Filled ENTER orders and open EXIT orders do not count toward the configured working ENTER count.
Range
The percentage used to determine the spacing of the initial ENTER ladder.
Example:
Levels = 10
Range = 2%
The step percentage is:
Step Percentage = Range / Levels
Therefore:
2% / 10 = 0.2% per level
Range defines the preferred quoting density around the current ladder anchor.
Range is not a hard maximum distance. The ladder may extend farther downward when price ranges are locked.
Scalp
The percentage above each ENTER fill price where the matching EXIT is placed.
Example:
Scalp = 1%
ENTER fill = 100
EXIT price = 101
Formula:
EXIT Price = ENTER Fill Price × (1 + Scalp Percentage)
Amount
The total USD amount assigned to the working ENTER ladder.
Example:
Amount = $100
Levels = 10
Each working ENTER receives:
$100 / 10 = $10
Formula:
Level Amount = Total Amount / Levels

3. Ladder Anchor
The ladder anchor is the market price from which the current ENTER ladder is generated.
When the strategy starts:
Ladder Anchor = Current Market Price
When a full upward reprice occurs:
Ladder Anchor = Current Market Price at Reprice
The anchor remains unchanged while the market moves downward.

4. ENTER Ladder Generation
Each ENTER level is generated below the ladder anchor using the configured step percentage.
Current compounded formula:
ENTER Price =
Ladder Anchor × (1 - Step Percentage) ^ Level Number
Example:
Anchor = 100
Step = 1%
The ladder is:
Level 1 = 99.0000
Level 2 = 98.0100
Level 3 = 97.0299
The strategy currently uses compounded percentage spacing rather than fixed-dollar spacing.

5. Working ENTER Order Rule
The strategy should maintain the configured number of working ENTER orders.
Example:
Levels = 10
Normal target:
ENTER_OPEN count = 10
When one ENTER fills:
10 ENTER_OPEN
→ 1 ENTER fills
→ 9 ENTER_OPEN
→ 1 replacement ENTER is created lower
→ 10 ENTER_OPEN
The replacement order is placed below the deepest active grid position.

6. ENTER Fill Rule
An ENTER order is considered filled when the execution is confirmed by Kraken.
During DRY_RUN testing, an ENTER is simulated as filled when:
Current Market Price <= ENTER Price
After an ENTER fills, the strategy must:
	1	Move the ENTER order from open orders to closed orders.
	2	Mark the level as ENTER_FILLED.
	3	Place the matching EXIT order.
	4	Mark the level as EXIT_OPEN.
	5	Lock the level’s surrounding price range.
	6	Create a new lower ENTER order so the configured working ENTER count is restored.

7. Matching EXIT Rule
Every filled ENTER creates one matching EXIT.
Formula:
EXIT Price =
ENTER Fill Price × (1 + Scalp Percentage)
Each EXIT remains tied to its original ENTER through:
source_enter_txid
and through the matching row in the levels table.
An EXIT must never be canceled merely because the ENTER ladder is repriced.

8. Accumulation Rule
The current strategy sells enough asset at the EXIT price to recover the original USD amount assigned to that level.
Formula:
EXIT Quantity =
Level USD Amount / EXIT Price
Because the ENTER quantity was purchased at a lower price:
ENTER Quantity >
EXIT Quantity
The difference is retained as accumulated asset.
Formula:
Accumulated Quantity =
ENTER Quantity - EXIT Quantity
Example:
ENTER:
$10 at $100
Quantity = 0.10

EXIT:
Recover $10 at $101
Quantity = 0.0990099

Accumulated asset:
0.10 - 0.0990099
= 0.0009901
The strategy therefore retains the trading profit in the traded asset rather than realizing the profit as additional USD.

9. Price-Range Ownership Rule
A filled ENTER does not lock only one exact price.
It locks the open interval between the neighboring grid boundaries.
Example:
Upper boundary = 100
Filled level   = 99
Lower boundary = 98
Locked range:
98 < price < 100
The boundary prices themselves remain allowed.
Therefore:
98.00   allowed
98.50   blocked
99.00   blocked
99.75   blocked
100.00  allowed
The range becomes locked only after the ENTER fills.
The range remains locked while the level is in either state:
ENTER_FILLED
EXIT_OPEN
An ENTER_OPEN order does not lock its entire range. It only occupies its exact working price.

10. Locked-Range Enforcement
Before placing any new ENTER order, the strategy checks every active locked range.
A candidate ENTER is rejected when:
lock_lower < candidate_price < lock_upper
The strategy must continue searching through lower grid positions until it finds an allowed price.
This means skipped locked ranges do not reduce the configured number of working ENTER orders.

11. Downward Market Movement
The strategy does not reprice the ladder downward.
When the market falls:
	1	ENTER orders may fill.
	2	Each fill creates its own EXIT.
	3	Each filled level becomes range-locked.
	4	One replacement ENTER is placed lower.
	5	The ladder extends downward as necessary.
This keeps the strategy active during a prolonged market decline.

12. Upward Reprice Trigger
A full ENTER-ladder reprice occurs when the market rises by at least one configured step above the current ladder anchor.
Formula:
Reprice Trigger =
Ladder Anchor × (1 + Step Percentage)
Example:
Anchor = 100
Step = 1%
Trigger = 101
The reprice occurs when:
Current Market Price >= Reprice Trigger

13. Full Upward Reprice Rule
When a full upward reprice is triggered, the strategy must:
	1	Fetch every ENTER_OPEN order.
	2	Cancel every ENTER_OPEN order.
	3	Move those orders to canceled orders.
	4	Mark their level rows as CANCELED.
	5	Leave all ENTER_FILLED and EXIT_OPEN levels untouched.
	6	Set the new ladder anchor to the current market price.
	7	Rebuild the working ENTER ladder from grid position 1 below the new anchor.
	8	Skip any candidate price inside an active locked range.
	9	Continue farther downward until the configured number of working ENTER orders exists.
The entire open ENTER ladder moves together.
The strategy must never cancel an active EXIT during an upward reprice.

14. Extended Ladder Rule
Locked ranges may cause many normal grid positions to be skipped.
The strategy should continue generating lower candidate positions until it restores the configured number of working ENTER orders.
Therefore:
Levels = 10
means:
Maintain 10 working ENTER orders
It does not mean those 10 orders must always remain inside the original Range percentage.
The ladder may extend farther below the anchor while higher price ranges are owned by active EXIT cycles.
This behavior is intentional.

15. EXIT Fill Rule
An EXIT is complete when Kraken confirms the order is fully filled.
During DRY_RUN testing, an EXIT is simulated as filled when:
Current Market Price >= EXIT Price
After an EXIT fills, the strategy must:
	1	Move the EXIT from open orders to closed orders.
	2	Mark the matching level as EXIT_FILLED.
	3	Unlock the price range previously owned by that level.
	4	Make that range eligible for future ENTER orders.
	5	Maintain the configured working ENTER count.
The strategy does not necessarily place a new ENTER immediately at the old filled price.
Instead, the newly unlocked area becomes available during normal ladder maintenance or the next upward reprice.

16. Ladder Recovery After EXIT Fills
As EXIT orders fill, their locked ranges are released.
During future upward reprices, the strategy can place ENTER orders inside those newly available areas.
This naturally allows the ENTER ladder to rise as completed trade cycles release previously owned price ranges.
The ladder therefore moves upward one available opportunity at a time while preserving unfinished positions.

17. One Active Cycle Per Price Band
Only one owned trading cycle may control a price band at a time.
The lifecycle is:
ENTER_OPEN
→ ENTER_FILLED
→ EXIT_OPEN
→ EXIT_FILLED
A new ENTER may not be placed inside that level’s locked band while the state is:
ENTER_FILLED
or
EXIT_OPEN
After the state becomes:
EXIT_FILLED
the band becomes available again.

18. State Definitions
ENTER_OPEN
The ENTER order is currently working.
The exact ENTER price is occupied.
The surrounding band is not yet locked.
ENTER_FILLED
The ENTER completed.
The price band is locked.
The EXIT is being prepared or submitted.
EXIT_OPEN
The matching EXIT is working.
The price band remains locked.
EXIT_FILLED
The full ENTER-and-EXIT cycle completed.
The price band is unlocked.
CANCELED
The ENTER order was canceled, normally because of a full upward reprice.
Canceled levels do not lock a price range.

19. DRY_RUN Rules
When:
DRY_RUN = True
the strategy must not submit or cancel real Kraken orders.
Dry-run order identifiers should be synthetic, such as:
DRY_ENTER_...
DRY_EXIT_...
Dry-run reconciliation with Kraken should be skipped because synthetic transaction IDs do not exist at Kraken.
Live public ticker prices may still be used to simulate fills.

20. Websocket Recovery Rule
If the public ticker or private execution websocket disconnects:
	1	Log the disconnection.
	2	Wait for the configured reconnect delay.
	3	Reconnect automatically.
	4	Resume normal processing.
	5	Reconcile orders after private websocket recovery when not in DRY_RUN mode.
A temporary websocket disconnection must not terminate the strategy.

21. Database Source of Truth
The strategy uses these main tables:
multi_marketmaker_sigma.open_orders
multi_marketmaker_sigma.closed_orders
multi_marketmaker_sigma.canceled_orders
multi_marketmaker_sigma.levels
The levels table connects each ENTER cycle to:
ENTER transaction ID
EXIT transaction ID
ENTER price
EXIT price
ENTER quantity
EXIT quantity
accumulated quantity
lock lower boundary
lock upper boundary
current state
The levels table is the primary source for reconstructing and verifying each trading cycle.

22. Core Strategy Summary
MULTI-MARKETMAKER-SIGMA follows these primary rules:
1. Always maintain the configured number of working ENTER orders.

2. Each ENTER fill creates one matching EXIT.

3. Each filled ENTER owns a surrounding price band.

4. A locked band cannot be reused until its EXIT fills.

5. The ladder never reprices downward.

6. Filled orders cause the ladder to extend lower.

7. An upward movement of one step reprices the entire open ENTER ladder.

8. Active EXIT orders are never canceled during an ENTER-ladder reprice.

9. Rebuilt ladders skip all locked ranges.

10. The ladder may extend beyond the configured Range to maintain the desired number of working ENTER orders.

11. EXIT fills release locked ranges.

12. Released ranges allow the active ENTER ladder to move upward again.

13. Trading profit is currently accumulated in the traded asset.
