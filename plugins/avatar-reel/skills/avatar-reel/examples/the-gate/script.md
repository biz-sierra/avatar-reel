# Example: "The Gate" (a belief-breaking reel, ~45s)

The reel this skill was built from. A local-marketing agency owner breaks one belief for small-business owners: *"My website looks good, so Google and AI can find me."* All business names in it are fictional.

| | |
|---|---|
| Job | Break one belief. No call to action. |
| The break | Your website isn't just for people anymore. A machine reads it first, and one setting can lock it out. |
| Picture that runs through it | A building inspector who can't walk inside. He only gets the paperwork. |
| Peer example | "The shop across town" (a peer the viewer measures themselves against, never a giant) |
| Countable cost | Who ChatGPT names when someone asks for a chiropractor open on Saturday |
| Length | 202 words → 44.9s at the standard cadence |
| Reading level | Flesch-Kincaid grade 4.4 |

## Script

```
Most business owners don't know there's one setting on their website
that decides if AI can read it, or if it's invisible.

That's not on you. Your site was built for people.
Photos, reviews, a big Book Now button.

But Google and ChatGPT don't see your site the way a customer does.
Think of a building inspector who can't walk inside.
All he gets is the paperwork.

That setting is the gate. One small file, or one switch in your
website settings, can tell AI to stay out.
Most owners have never checked theirs.

Gate locked, paperwork blank, and the inspector moves on
to the shop across town. That's who ChatGPT names when someone
asks for a chiropractor open on Saturday.

Here's the paperwork we fill out.
We open the gate.
We put a hidden label on every page that says what you do,
where you are, and when you're open.
We make your site and your Google profile match, word for word.
And we hand Google a map of every page, so nothing gets missed.

Your website isn't just for people anymore. A machine reads it first.
And every week your gate stays locked, the shop across town gets the call.
```

## Plain words on camera → the technical thing (for the creator, never on screen)

| Said on camera | Technical thing |
|---|---|
| the setting / the gate / one small file | robots.txt rules for AI crawlers (GPTBot, OAI-SearchBot, PerplexityBot, ClaudeBot) |
| one switch in your website settings | host or CDN AI-bot blocking (e.g. a site builder's AI-crawler toggle, Cloudflare "Block AI bots") |
| hidden label on every page | schema markup / JSON-LD |
| site and Google profile match, word for word | NAP consistency (name, address, phone) |
| a map of every page | XML sitemap |

## Accuracy pass (do this on every script)

The first draft said "decides if your business can appear in AI search." That's falsifiable: blocking AI crawlers stops them reading the **site**, but AI can still mention a business from its Google profile or other sites. Tightened to "decides if AI can read **it**" (the website). Every claim should survive someone trying to prove it wrong.

## How it was cut

See `timeline.mjs` next to this file: every cut is anchored to a spoken phrase. Face-only on the hook, the empathy line ("That's not on you"), the turn ("Here's the paperwork") and the belief-break line; a picture panel on almost everything else; the gate clip comes back three times as a callback; it ends on a panel payoff (the call goes to the competitor) with a hard cut.

The **plumber version** of this same reel changed one spoken line ("…asks who can fix a water heater today"), re-rendered only that sentence's head (~12 HeyGen credits), and swapped the niche copy in the graphics. See "Niche clones" in `SKILL.md`.
