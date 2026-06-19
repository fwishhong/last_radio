# Steam Tags, Categories, Pricing

> Settings to use in the Steamworks "Edit Store Page" form.

## Category (Primary + Optional)

| Slot       | Choice          |
|------------|-----------------|
| Primary    | Indie           |
| Secondary  | Strategy        |
| Secondary  | RPG             |
| Secondary  | Adventure       |

## Genre tags (pick 5 max, ranked by relevance)

1. Strategy
2. Survival
3. Indie
4. RPG
5. Adventure

## Other tags (use what fits naturally)

- Single Player
- Atmospheric
- Story Rich
- Choices Matter
- Resource Management
- Tactical
- 2D
- Dark
- Mystery
- Post-apocalyptic

## Platform tags

- Windows
- macOS
- Linux

## Price

| Locale   | Suggested USD | Local currency       |
|----------|---------------|----------------------|
| All      | $2.99 USD     | Steam auto-converts  |
| China    | ¥18 RMB       | Set explicitly       |
| Other    | Auto          | Default conversion   |

> $2.99 keeps the impulse-buy tier while $1 won't make Valve's regional
> rounding look weird in JPY/KRW. RMB is the headline price mentioned in
> the design doc.

## Release visibility (launch checklist)

| Phase       | Days relative | Visibility       | Purchasing     |
|-------------|---------------|------------------|----------------|
| Pre-launch  | T-14          | Hidden           | Hidden         |
| Beta        | T-7           | Friends-only     | Hidden         |
| Wishlist    | T-7 → T-1     | Visible          | Hidden         |
| Launch      | T-0           | Visible          | Available      |
| Day-1 patch | T+0 → T+3     | Visible          | Available      |

## Reviews / review-bomb mitigation

- Build "no achievements for skipping tutorial" so completionists don't
  feel forced to grind.
- The 失败夜 report screens are designed to make a failed run feel
  progress, not punishment — verify on Steam forums during beta.
- No microtransactions → nothing to refund-bomb over.

## What's NOT in the store page

Per the doc's Scope cut: no Modding, no Workshop, no Trading Cards,
no DLC banners, no season-pass marketing, no leaderboards, no
cross-promotion banners for other titles.
