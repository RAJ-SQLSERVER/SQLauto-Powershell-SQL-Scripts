function ConvertTo-DataTable
{
 <#
 .EXAMPLE
 $DataTable = ConvertTo-DataTable $Source
 .PARAMETER Source
 An array that needs converted to a DataTable object
 #>
[CmdLetBinding(DefaultParameterSetName="None")]
param(
 [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='What computer name would you like to target?')][System.Array]$Source
)

$Columns = $Source[0].psobject.properties | select Name, TypeNameOfValue

$DataTable = New-Object System.Data.DataTable
foreach ($Column in $Columns)
{
    $Col =  new-object Data.DataColumn("$($Column.Name)","$($Column.TypeNameOfValue)")
    $DataTable.Columns.Add($col) 
}
#For each row (entry) in source, build row and add to DataTable.
foreach ($Entry in $Source)
{
     $Row = $DataTable.NewRow()
     foreach ($Column in $Columns.Name)
     {
        $Row["$($Column)"] = if($Entry.$Column -ne $null){($Entry | Select-Object -ExpandProperty $Column) -join ', '}else{$null}
     }
     $DataTable.Rows.Add($Row)
}

#Validate source column and row count to DataTable
if ($Columns.Count -ne $DataTable.Columns.Count){
 throw "Conversion failed: Number of columns in source does not match data table number of columns"
}
else{ 
 if($Source.Count -ne $DataTable.Rows.Count){
 throw "Conversion failed: Source row count not equal to data table row count"
 }
 #The use of "Return ," ensures the output from function is of the same data type; otherwise it's returned as an array.
 else{
 Return ,$DataTable
 }
 }
}