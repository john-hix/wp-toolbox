<?php
  $d = new DateTime($argv[1]);
  echo serialize($d);
  die;
 ?>
