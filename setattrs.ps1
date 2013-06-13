$files = get-childitem .
foreach($f in $files){
  (get-item $f).Attributes = 'Normal'
}