# notify-hub

## Overview
NotifyHub is a personal notification aggregation system. Cloud systems and automated processes push events to a central backend. Those events are stored in a timeline and surfaced to the owner across iPhone, iPad, and Mac via native apps. Urgent events trigger immediate push notifications via Pushover. Non-urgent events are batched and delivered on an hourly schedule with configurable quiet hours.

## Goals

* Single ingest API for any cloud system to push events to
* Persistent timeline of all events, queryable by client apps
* Immediate delivery for urgent events via Pushover
* Batched hourly digest for non-urgent events
* No notification spam during quiet hours (except urgent)
* Native apps on iPhone, iPad, and Mac from a single Swift codebase
* Lightweight, low-cost infrastructure

