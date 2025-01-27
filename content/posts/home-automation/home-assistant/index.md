---
title: "Home Assistant: Turning the lights on"
date: 2025-01-26T20:00:00-05:00
categories:
  - home-automation
tags:
  - home-automation
  - home-assistant
  - zigbee2mqtt
  - zigbee
  - mqtt
  - lights
---

I am not new to smart devices, they have been around for some time after all. I
have a few WiFi smart light bulbs in my home and I previously used a smart
outlet to power on my espresso machine in the morning. However, I have grown
tired of buying all into one ecosystem to tie everything together. Vendors have
their own implementation, their own app, their own cloud service. Additionally,
the thought of IoT devices calling home irks me. This is exacerbated by the [US
considering to ban TP-Link devices][1], given that most of my WiFi smart
devices are TP-Link. All that said, I decided to give [Home Assistant][2] a
try, and this is my journey.

[1]: https://www.wsj.com/politics/national-security/us-ban-china-router-tp-link-systems-7d7507e6
[2]: https://home-assistant.io

## Technology

The big question, and one I am sure asked by many, what technology do
I start with? There are several standardized protocols such as ZigBee, Z-Wave,
Matter/Threads, etc. As a newcomer, it feels daunting. After all, I don't want
to buy into one technology only for it to be replaced by another down the road.
Luckily with Home Assistant, I can tie most things together thanks to their
numerous integrations.

I decided to start with ZigBee. I won't compare and contrast the different
technologies, but these features sold me:

- **No WiFi** - ZigBee devices operate on the 2.4 GHz band, also shared by
  WiFi, but at different channels and with their own protocol stack. This is
  appealing because I can keep devices off my network. I have IoT devices on
  their own VLAN with ACLs, but it would be great if I could minimize the
  number of devices.

- **Multiple Vendors** - Multiple vendors sell ZigBee devices, giving you the
  ~~paradox~~freedom of choice.

It's not all rainbow and sunshine. ZigBee devices have their own issues such as
limited range, slow updates, and vendors with problematic firmware. Even so, I
felt the positives outweighed the negatives.

## The Coordinator

ZigBee requires a coordinator to communicate with devices and join them your
ZigBee network. Since I run Home Assistant in a Proxmox Cluster with high
availability[^1], I didn't want to passthrough a USB dongle. What if I have to
migrate the VM to another node? Luckily, there are network coordinators that
connect to the network[^2], which I feel is a better fit.

[^1]: Many people use the name HA to reference Home Assistant, which confused
    me at first because HA is also used to refer to high availability.

[^2]: I know I just talked about how I want to minimize devices on my network,
    but for the coordinator I'll make an exception since it does reduce the
    surface area.

I chose to go with the [TubesZB CC2652 P7 PoE Coordinator][3]. Granted, I was
not well versed with coordinators and firmware when purchasing, but it works
really well for me. I also like that it supports PoE---the less cables the
better.

[3]: https://tubeszb.com/product/cc2652p7-zigbee-to-poe-coordinator-2023/

## Home Assistant and Zigbee2MQTT

Being a power user, I did not go with Home Assistant OS (HAOS). From what I can
see, the only benefit---other than the simple installation---is installing
Add-Ons and automatic updates. Add-Ons are other applications managed by Home
Assistant, so I don't feel like I'm losing functionality if I run those
applications myself. I deployed a Home Assistant container in an AlmaLinux[^3]
virtual machine, using [Podman Quadlets][4] with [`podman-auto-update`][5] to
handle updates.

[^3]: I had the opportunity to work with Red Hat consultants, and they had
    not-so-nice things to say about Rocky linux. Obviously they want to push
    their own product, but one of the consultants did say "at least use
    AlmaLinux," so that's what I stuck with.

[4]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
[5]: https://docs.podman.io/en/latest/markdown/podman-auto-update.1.html

Multiple anecdotes claim [Zigbee2MQTT (Z2M)][6] has better support for devices
than Home Assistant's own ZigBee implementation (ZHA). So I went that route, and
I'm glad I did. Being able to inspect traffic by subscribing to an MQTT topic is
a welcomed benefit. I run ZigBee2MQTT and an MQTT broker, [Mosquitto][7], as
containers on the same instance.

[6]: https://www.zigbee2mqtt.io/
[7]: https://mosquitto.org/

## Devices

To start out, I got a few [Philips Hue][8] light bulbs. They're not cheap, but
the consensus is that they're the best on the market.

[8]: https://www.philips-hue.com/en-us/p/hue-white-and-color-ambiance-a19-e26-smart-bulb-60-w-2-pack/046677548612

For switches, [Sonoff SNZB-01P][9] buttons and a [Lutron Aurora smart bulb
dimmer][10]. Originally I was going to get a wall mounted dimmer and 3D print
light switch covers, but the Aurora dimmer does both and looks great too.

[9]: https://sonoff.tech/product/gateway-and-sensors/snzb-01p/
[10]: https://residential.lutron.com/us/en/stand-alone-controls/smart-bulb-dimmer

I already have a few ESP32s with temperature and humidity sensors reporting to a
Prometheus instance, but I figured I should get something that looks nicer than
a breadboard and cables. So I got a couple of [Sonoff SNZB-2D Temperature and
Humidity sensors][11]. Home Assistant has a [Prometheus integration][12] that
I'm eager to try out.

[11]: https://sonoff.tech/product/gateway-and-sensors/snzb-2d/
[12]: https://www.home-assistant.io/integrations/prometheus/

## My First Automation

It's finally time to start automating my home! Most people probably start off by
tying a switch to a light, something easily achieved using Home Assistant's
automations.

Not me, though. I wanted my lights to gradually fade in the morning over
30 minutes. Similar to the [Philips Wake-up Light][13].

[13]: https://www.usa.philips.com/c-p/HF3471_60/wake-up-light

The Hue lights support a `transition` field, but I found it wasn't sufficient to
solve my problem for a couple of reasons:

1. The transitions max out at 5 minutes.

2. HA will report the final transition state on the UI when the lights mid
   transition.

That is not to say the `transition` field is useless. Without it, the lights
fade in a step curve. Here is a graph showing the change in brightness with and
without using `transition`:

{{< image src="fade-comparison.svg" alt="Light Fading" position="center" >}}

In hindsight, it seems obvious. Even if I reduced the interval from 5 minutes to
1 second, the change in brightness is still noticeable. With some help from the
lights, though, we can get pretty close to a smooth transition while maintaining
an accurate state in Home Assistant's UI.

For the remainder of this post, I experiment with 4 different automation
implementations for Home Assistant: YAML, HA Python Scripts, AppDaemon, and
pyscript. Being a software engineer, I have some strong opinions. That is not to
say what you choose is wrong, I firmly believe that you should use what you are
most comfortable with.

### YAML

Ah, the ubiquitous markup language. Seen often in configuration files,
Kubernetes, Ansible, and I guess Home Assistant too. That's not a bad thing.
Despite common criticisms of YAML, I find it perfectly adequate for
configuration files in my own applications. I do, however, have a problem with
using YAML as a programming language.

Let's look at an example straight from Home Assistant's documentation:

```yaml
# Turns on lights 1 hour before sunset if people are home
# and if people get home between 16:00-23:00
- alias: "Rule 1 Light on in the evening"
  triggers:
    # Prefix the first line of each trigger configuration
    # with a '-' to enter multiple
    - trigger: sun
      event: sunset
      offset: "-01:00:00"
    - trigger: state
      entity_id: all
      to: "home"
  conditions:
    # Prefix the first line of each condition configuration
    # with a '-'' to enter multiple
    - condition: state
      entity_id: all
      state: "home"
    - condition: time
      after: "16:00:00"
      before: "23:00:00"
  actions:
    # With a single action entry, we don't need a '-' before action - though you can if you want to
    - action: homeassistant.turn_on
      target:
        entity_id: group.living_room
```

At face value, this isn't bad at all. You define a trigger, optional conditions,
and actions to perform. I believe these simple automations are what YAML excels
at. You can even leverage Home Assistant's tracing ability to debug.

Now let's take a look at my attempt to automate fading lights,

```yaml
- alias: Fade lights on
  mode: restart
  triggers:
    # Use a button to trigger the automation for testing
    - trigger: mqtt
      topic: zigbee2mqtt/master_bedroom_light_switch/action
      payload: double
  actions:
    - variables:
        entity_id: light.master_bedroom_ceiling_lights
        start_time: "{{ as_timestamp(now()) }}"
        brightness_start: 2
        brightness_end: 192
        duration: 1800  # 30 minutes
        interval: 1.0
    - repeat:
        until: "{{ (as_timestamp(now()) - start_time) > (duration + 1.0) }}"
        sequence:
          - variables:
              elapsed: "{{ as_timestamp(now()) - start_time }}"
              t: "{{ min(1.0, (elapsed / duration) | round(3)) }}"
              brightness: "{{ ((brightness_start * (1.0 - t)) + (brightness_end * t)) | int }}"

          - action: light.turn_on
            target:
              entity_id: "{{ entity_id }}"
            data:
              brightness: "{{ brightness }}"
              transition: "{{ interval }}"

          - delay: "{{ interval }}"
```

It works, but I feel dirty writing this. Using `repeat` for loops and
expressions in Jinja2 turns YAML into a programming language.[^4]

[^4]: Ansible also does this, but I hold the opinion that if you're embedding
    too much logic in your ansible tasks, you should look into writing a custom
    module in python instead.

On top of that, there are some weird quirks that you get when you template
YAML. For example,

```yaml
t: "{{ min(1.0, (elapsed / duration) | round(3)) }}"
```

The `round(3)` here is necessary because this expression can produce a small
number that is rendered in scientific notation (e.g. `2.314e-5`). When the
value is parsed, it is interpreted as a string rather than a float. So either
you round up to avoid scientific notation, or convert to float when used.

I also found it tedious to debug even with Home Assistant's tracing---which is
actually quite nice. So I set out to find an alternative, starting with Home
Assistant's built in `python_scripts` integration.

An aside: in my research I encountered [this reddit post][14] where the top
comment states that automations in YAML are declaration and not imperative. I
take issue with this classification, because `sequence`, `repeat`, `if` are
means of control flow and constructs of imperative languages. Unless an
automation is a single action with a desired state (e.g. `light.turn_on`), the
automation is not declarative.

[14]: https://www.reddit.com/r/homeassistant/comments/12oqayq/stupid_question_why_use_yaml_and_not_an_actual/

### Python Scripts

Home Assistant comes with a built-in [Python Scripts][15] integration. I
thought this would satisfy my desire for a programming language and not YAML
masquerading as one.

[15]: https://www.home-assistant.io/integrations/python_script/

I took my automation from above and ported it to Python Scripts:

```python
entity_id = "light.master_bedroom_ceiling_lights"
brightness_start = 2
brightness_end = 192
duration = 15
interval = 1.0

def lerp(v0, v1, t):
    return (v0 * (1.0 - t)) + (v1 * t)

logger.info(f"Starting transition of {entity_id}")
start_time = time.time()

while (elapsed := time.time() - start_time) < duration + 0.5:
    t = min(1.0, elapsed / duration)
    brightness = int(lerp(brightness_start, brightness_end, t))

    logger.info(f"Updating {entity_id}, t = {t:3f}, brightness = {brightness}")
    hass.services.call("light", "turn_on", {
        "entity_id": entity_id,
        "brightness": brightness,
        "transition": interval,
    })

    time.sleep(interval)

logger.info(f"Transition for {entity_id} complete")
```

This is feels more at home. I like that the scripts are exposed as actions
within Home Assistant, and you can define field specifications that are shown
as UI elements. However, the restricted Python environment is a dealbreaker for
me. For example, you cannot define your own classes because the required
builtins are not exposed.

The documentation calls out the limitations, and offers two alternatives:

> It is not possible to use Python imports with this integration. If you want
> to do more advanced scripts, you can take a look at [AppDaemon][16] or
> [pyscript][17].

[16]: https://appdaemon.readthedocs.io/en/latest/
[17]: https://github.com/custom-components/pyscript

For a script this simple, I probably don't need imports or classes. But if I
want to create complex automations, such as call a remote service, guess I'm
out of luck. I don't want to maintain scripts in multiple environments so let's
move on to the next.

### AppDaemon

AppDaemon handles automation a different way. It is not a native Home Assistant
integration, but a separate application that connects to Home Assistant via its
WebSocket API. I ported my automation over, and this is what I ended up with:

```python
import time
import hassapi as hass

def lerp(v0, v1, t):
    return (v0 * (1.0 - t)) + (v1 * t)

class LightFadeContext:
    def __init__(self, entity_id, brightness_start, brightness_end, duration, interval):
        self.entity_id = entity_id
        self.brightness_start = brightness_start
        self.brightness_end = brightness_end
        self.duration = duration
        self.interval = interval
        self.start_time = time.time()

class LightFader(hass.Hass):
    def initialize(self):
        self.listen_event(self.run, "APP_FADE_LIGHTS_IN")

    def run(self, event, data, args):
        ctx = LightFadeContext(
            data.get("entity_id", "light.master_bedroom_ceiling_lights"),
            data.get("brightness_start", 2),
            data.get("brightness_end", 192),
            data.get("duration", 15),
            data.get("interval", 1.0),
        )

        self.log(f"Starting transition of {ctx.entity_id}")
        self.run_in(self._fade_loop, 0, ctx=ctx)

    def _fade_loop(self, args):
        ctx = args.get("ctx", None)
        if not ctx:
            return

        elapsed = time.time() - ctx.start_time
        if elapsed > ctx.duration + 0.5:
            self.log(f"Transition for {ctx.entity_id} complete")
            return

        t = min(1.0, elapsed / ctx.duration)
        brightness = int(lerp(ctx.brightness_start, ctx.brightness_end, t))

        self.log(f"Updating {ctx.entity_id}, t = {t:3f}, brightness = {brightness}")
        self.call_service(
            "light/turn_on",
            entity_id=ctx.entity_id,
            brightness=brightness,
            transition=ctx.interval,
        )

        self.run_in(self._fade_loop, ctx.interval, ctx=ctx)
```

Whoa, that's a screenful! AppDaemon discourages use of `time.sleep()` and
recommends `self.run_in()` to schedule functions for later. The result is a
callback-style of programming, so you have to maintain state between function
calls yourself. AppDaemon does offer an asynchronous API that would likely
reduce the complexity, but I decided to stick to its synchronous API for
demonstration.

One downside is that services don't populate in Home Assistant's UI. Instead,
you communicate by registering for events or triggers in the `initialize()`
method. It's not a dealbreaker, but it does mean stuff is hidden from HA's point
of view.

You have the power of Python with nothing---except maybe the scheduler---holding
you back. I don't hate it, but I also don't love it.

### pyscript

[pyscript][17] is a custom component for Home Assistant. It is not installed by
default, but is easy to install yourself.

Like HA's Python Scripts, pyscript exposes your scripts as actions within Home
Assistant. You define you services using decorators, and you can even provide a
YAML specification in your function's docstring. Pretty neat! Let's port that
sucker over:

```python
import time

def lerp(v0, v1, t):
    return (v0 * (1.0 - t)) + (v1 * t)

@service
def fade_lights_in(
    entity_id: str,
    brightness_start: int = 2,
    brightness_end: int = 192,
    duration: int = 15,
    interval: float = 1.0,
):
    log.info(f"Starting transition of {entity_id}")
    start_time = time.time()

    while (elapsed := time.time() - start_time) < duration + 0.5:
        t = min(1.0, elapsed / duration)
        brightness = int(lerp(brightness_start, brightness_end, t))

        log.info(f"Updating {entity_id}, t = {t:3f}, brightness = {brightness}")
        light.turn_on(
            entity_id=entity_id,
            brightness=brightness,
            transition=interval,
        )

        task.sleep(interval)

    log.info(f"Transition for {entity_id} complete")
```

Overall, it is a pretty good experience. It's just as concise as the Python
Scripts implementation, and I can define classes and import libraries. Unlike
Python Scripts, pyscript automatically reloads your file when modified, which is
a plus when developing.

It does have one quirk: it is not your typical CPython implementation under the
hood. pyscript parses and executes the python code itself. This is done to
generate asynchronous code that does not block Home Assistant. It's giving
[gevent][18] vibes, which I find pleasurable to work with.

[18]: http://www.gevent.org/

### Manual Intervention

My goal is to fade the lights on over 30 minutes. During this time I can see
myself turning the lights completely on if I wake up early. Or, turning them off
if I want to sleep in. I know I shouldn't, but sleepy me is not a person you can
reason with! With the automation running in the background, a change in
brightness will revert back during the next iteration. I have to somehow handle
manual intervention.

In my early stages of experimenting, I handled manual intervention by comparing
state attributes before the `light.turn_on` service call to the values set in
the previous iteration. If the attributes differ from the last call, I know
something external to the automation made a change. This somewhat works, but I
found it to be finicky. For example, when the lights are off, Home Assistant
reports the brightness as `None` instead of `0`.[^5] This complicates the logic
flow, since now I have to compare against state as well as brightness.
Additionally, my Philips Hue lights report a brightness of `2` after I pass in a
value of `1`! The inconsistency in state made it difficult to determine if the
light was modified externally. I hoped for a better way, and it turns out Home
Assistant provides a *State Context* that yields reliable results.

[^5]: The state reported by Zigbee2MQTT **does** carry the `brightness` value
    even when off. So Home Assistant is internally setting entity state
    attributes to `None` when in an off state.

Here is an implementation in YAML that works quite well:

```yaml
- alias: Fade lights on
  triggers:
    - trigger: mqtt
      topic: zigbee2mqtt/master_bedroom_light_switch/action
      payload: double
  actions:
    - variables:
        entity_id: light.master_bedroom_ceiling_lights
        start_time: "{{ as_timestamp(now()) }}"
        brightness_start: 2
        brightness_end: 192
        last_brightness: 0
        duration: 15
        interval: 1.0
    - repeat:
        until: "{{ (as_timestamp(now()) - start_time) > (duration + 1.0) }}"
        sequence:
          - variables:
              elapsed: "{{ as_timestamp(now()) - start_time }}"
              t: "{{ min(1.0, (elapsed / duration) | round(3)) }}"
              brightness: "{{ ((brightness_start * (1.0 - t)) + (brightness_end * t)) | int }}"

          - action: light.turn_on
            target:
              entity_id: "{{ entity_id }}"
            data:
              brightness: "{{ brightness }}"
              transition: "{{ interval }}"

          - delay: "{{ interval }}"

          - variables:
              state_context_id: >-
                {{ (states
                    | selectattr( 'entity_id', 'eq', entity_id)
                    | first).context.id }}

          - if:
              - condition: template
                value_template: >-
                  {{ context.id != state_context_id }}
            then:
              - action: system_log.write
                data:
                  message: "{{ context.id }} != {{ state_context_id }}"
              - stop: >-
                  Entity modified outside of script, terminating"
```

The entity's state context is modified to the context of the last call that
induced a change. This is great, because I can check if the context matches my
automation's context and stop when it does not.

Out of all the Python solutions, only `pyscript` exposes the context to
scripts.[^6] They don't mention it in their documentation, but after reading the
source I was able to piece it together.

[^6]: In HA's Python Scripts, you don't have access to the `Context` object and
    it's not exposed in the state calls. In AppDaemon, a `Context` object is
    sent in the WebSocket API response but not passed around for use.

First, decorated functions can define a `context` keyword argument to obtain an
automatically generated context.

```python
from homeassistant.core import Context

@service
def fade_lights_in(..., context: Context | None = None):
```

This is merely convenience, we could generate our own `Context` object since we
have access to Home Assistant's modules.

Next, every service call should pass in the context.

```python
light.turn_on(..., context=context)
```

If you don't pass in the context, pyscript will generate one for the service
call and you can't compare it to a known value.

Finally, use `hass.states.get()` to obtain an entity's state. This requires
`hass_global_import: true` in pyscript's configuration. The `state.get()`  call
exposed by pyscript generates a new object that does not contain the state's
context.

Let's put it all together,

```python
import time

from homeassistant.core import Context

def lerp(v0, v1, t):
    return (v0 * (1.0 - t)) + (v1 * t)

@service
def fade_lights_in(
    entity_id: str,
    brightness_start: int = 2,
    brightness_end: int = 192,
    duration: int = 15,
    interval: float = 1.0,
    context: Context | None = None,
):
    log.info(f"Starting transition of {entity_id}")
    start_time = time.time()

    while (elapsed := time.time() - start_time) < duration + 0.5:
        t = min(1.0, elapsed / duration)
        brightness = int(lerp(brightness_start, brightness_end, t))

        log.info(f"Updating {entity_id}, t = {t:3f}, brightness = {brightness}")
        light.turn_on(
            entity_id=entity_id,
            brightness=brightness,
            transition=interval,
            context=context,
        )

        task.sleep(interval)

        st = hass.states.get(entity_id)
        if st.context != context:
            log.info(f"Encountered manual intervation for {entity_id}, terminating.")
            return

    log.info(f"Transition for {entity_id} complete")
```

It works just as well as the YAML implementation, but still suffers from a small
bug. If the `light.turn_on()` call does not induce a change then the state
context object does not update and the check call at the end fails. This is
shown by turning off the light and setting `brightness_start = 0`. Since
`brightness = 0` is equivalent to `state = off`, HA will not update the state
and will retain the original context. An easy fix is to check the context only
if it was updated since invocation.

```python
...

@service
def fade_lights_in(
    ...
):
    last_updated = state.get(entity_id).last_updated
    ...
    while (elapsed := time.time() - start_time) < duration + 0.5:
        ...
        st = hass.states.get(entity_id)
        if st.last_updated > last_updated and st.context != context:
            log.info(f"Encountered manual intervation for {entity_id}, terminating.")
            return

    ...
```

I definitely think pyscript is the clear winner here. It is a good compromise
between YAML and an external application such as AppDaemon.

## Conclusion

With that, my fading script is complete! Well, kind of. I went a bit further and
added support for color temperature, easing, and a YAML definition. [Feel free
to check it out.][19]

[19]: https://github.com/aldehir/pyscripts/blob/main/lights.py

I had loads of fun setting up my home automation, now I have to think of more
ideas to implement.
