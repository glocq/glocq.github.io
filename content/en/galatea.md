+++
title = "Galatea"
[extra]
language = "en"
translation = "galatea"
+++

This page is a demo of a draft of Galatea, a MIDI bridge that will allow you to
use a graphic tablet, a mouse or any other pointer device as a MIDI control
interface. The source code is available in
[this repository](https://github.com/glocq/galatea).

If you got here by chance, feel free to come back in a couple of weeks! The
interface should be improved and well documented by then.

<link href="/galatea/style.css" rel="stylesheet" />

<script src="/galatea/scripts/midi.js"    type="text/javascript"></script>
<script src="/galatea/scripts/pointer.js" type="text/javascript"></script>
<script src="/galatea/scripts/script.js"  type="text/javascript"></script>


<div id="galatea">
  <canvas id="controlSurface">
    Your browser does not support the canvas element.
  </canvas>
  <button type="button" id="fullscreenButton">Switch to Fullscreen</button>
  <ul id="settingsList">
    <li>
      <label>
        MIDI Outputs:
        <select id="midiOutputSelector"></select>
      </label>
    </li>
    <li>
      <label>
        Leftmost Pitch:
        <input id="lowestPitch" type="number" />
      </label>
    </li>
    <li>
      <label>
        Rightmost Pitch:
        <input id="highestPitch" type="number" />
      </label>
    </li>
    <li>
      <label>
        Pitch Bend Half Range (semitones):
        <input id="pitchBendHalfRange" type="number" />
      </label>
    </li>
  </ul>
</div>
