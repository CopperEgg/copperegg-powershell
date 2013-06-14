#
#	UserDefined.psm1 contains functions for retrieving metrics that may not be available using Get-Counter.
#
#
# Copyright (c) 2012,2013 CopperEgg Corporation. All rights reserved.
#


function LogExists_function{
  $path = "$env:userprofile\Desktop\log.txt"
  $result = (Test-Path -path $path)
  if( $result -eq 'True' ){
    return 1
  }
  return 0
}
Export-ModuleMember -function LogExists_function
