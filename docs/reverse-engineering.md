# Fighting game research with REA

This project uses [REA](https://github.com/morluto/rea) as an agent-assisted research tool for studying fighting game behavior and translating observations into original Godot mechanics.

## What REA is for

REA connects an agent to analysis tools for applications, websites, runtime behavior, and supported binary formats. It is not a Godot addon and does not automatically import game mechanics into this project. Use it to gather evidence about a feature, explain how it appears to work, and then implement an original version in this project.

## Investigation workflow

1. State one concrete question, such as how a reference game's lock-on camera behaves during an aerial approach.
2. Identify the authorized source to inspect: your own build, a supplied capture, a public interface, or software you have permission to analyze.
3. Ask REA to record the observations and evidence, including the target version, steps, timing, and limitations.
4. Separate observed facts from guesses. For fighting game behavior, note input timing, distance, animation/state changes, resource changes, and opponent response.
5. Turn the confirmed behavior into a small, original Godot change. Keep the reference notes here and the implementation in `scripts/` or `scenes/`.
6. Verify the change in the game and record any differences from the observation.

Useful investigation prompts:

- Map the visible state transitions for one move and identify the evidence for startup, active, and recovery phases.
- Observe how lock-on changes facing and movement during ground and aerial combat.
- Compare an opponent's defensive response to repeated, mixed, and delayed attacks.
- Document what changes when health, stun, or energy crosses a threshold.

Do not treat a single run as proof of hidden rules. Repeat observations, vary one input at a time, and record uncertainty. Use REA only with software and data you are authorized to inspect, and follow the target software's terms and applicable licenses.

## Agent setup

The official REA agent setup registers its MCP server and installs matching workflow instructions for supported agents, including Codex. After setup, restart the agent so the tools and instructions load. See the official [REA installation and setup guide](https://github.com/morluto/rea#quick-start) and [repository](https://github.com/morluto/rea) for current requirements and updates.
