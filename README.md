# Pluma API [A Newsletter & Subscriber Referral Tracker]

## What is this?

La Pluma was a daily spanish-language newsletter in the style of [Morning Brew](https://www.morningbrew.com/) deliviered during the 6 months of COVID quarantine restictions in Santiago, Chile.

## Key Features of the Project

- Hand-rolled referral tracking, resulting in VIP-tiers for subscribers who referred friends and family.
- A custom dashboard for subscribers to view their successful referrals (the API differentiated between referrals sent and referrals executed), as well as pending referrals.
- Mailchimp integration via Mailchimp Webhooks and a custom Mailchimp API library written in Elixir.
- Continuous database mirroring between Mailchimp's subscriber DB and a local PSQL instance for the API to assign and track relationships between subscribers based on UUID's injected into the Mailchimp subscriber DB.
- Scheduled sanitation routines to check Mailchimp/Local DB synchronicity and validity of data.
- Highly resilient Elixir/Phoenix-based API running on a single Render.com node.
- Push-to-deploy pipeline.
- A customized Wordpress front-end for the website (not in this repo).
- Hand-build HTML newsletter templates injected with custom subscriber information (including access to VIP content based on the subscriber's tier.

## Example Newsletter

Below is an example of a typical newsletter (*note that image links might be broken*):

[La Pluma Newsletter Example](https://nikokozak.github.io/pluma-newsletter-example/index.html)
