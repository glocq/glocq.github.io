+++
title = "Galatea"
[extra]
language = "fr"
translation = "galatea"
+++

Cette page est une démonstration d'une ébauche de Galatea, un pont MIDI
qui permet d'utiliser tablettes graphiques, souris et autres interfaces de
pointage comme interfaces de contrôle MIDI. Le code source est disponible sur
[ce répertoire](https://github.com/glocq/galatea).

Si vous êtes arrivée ici par hasard, n'hésitez pas à revenir dans quelques
semaines ! L'interface devrait être améliorée et bien documentée d'ici là.

<link href="/galatea/style.css" rel="stylesheet" />

<script src="/galatea/scripts/midi.js"    type="text/javascript"></script>
<script src="/galatea/scripts/pointer.js" type="text/javascript"></script>
<script src="/galatea/scripts/script.js"  type="text/javascript"></script>


<div id="galatea">
  <canvas id="controlSurface">
    L'élément canvas n'est pas compatible avec votre navigateur.
  </canvas>
  <button type="button" id="fullscreenButton">Passer en plein écran</button>
  <ul id="settingsList">
    <li>
      <label>
        Sorties MIDI :
        <select id="midiOutputSelector"></select>
      </label>
    </li>
    <li>
      <label>
        Hauteur côté gauche :
        <input id="lowestPitch" type="number" />
      </label>
    </li>
    <li>
      <label>
        Hauteur côté droit :
        <input id="highestPitch" type="number" />
      </label>
    </li>
    <li>
      <label>
        Demi-plage de modulation de hauteur (demi-tons) :
        <input id="pitchBendHalfRange" type="number" />
      </label>
    </li>
  </ul>
</div>
