package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	// "github.com/jojomi/go-spew/spew"
	"github.com/olekukonko/tablewriter"
	"github.com/pmylund/sortutil"
	log "github.com/withmandala/go-log"
)

var flagColorfullOutput = flag.String("colorfull", "false", "Print colorfull tables")
var flagPerComponetTable = flag.String("per-component-table", "true", "Prints a detailed table of changes for each component")
var flaghideReadOperations = flag.String("hide-read-operations", "true", "Hides Terraform read operations")

type resourceActions struct {
	action     string
	components []string
	accounts   []string
	regions    []string
}

type resourceAccounts struct {
	region     string
	components []string
	resources  []string
	actions    []string
}

func printColored(str string) {
	fmt.Println(fmt.Sprintf("\033[1;93m%s\033[0m", str))
}

func interfaceListToStringList(ifaceList []interface{}) []string {
	result := make([]string, len(ifaceList))
	for i, v := range ifaceList {
		result[i] = v.(string)
	}
	return result
}

/*
=============================================================
retruns the provider of a resource whether in root or child modules
=============================================================
*/
func getResourceProvider(rawPlan map[string]interface{}, resourceAddress string) string {
	var result string
	var resources interface{}
	if strings.HasPrefix(resourceAddress, "module.") {
		var re = regexp.MustCompile(`(?m)module\.([a-zA-Z\-_0-9]*)`)
		resourceModuleName := re.FindStringSubmatch(resourceAddress)[1]
		resourceAddress = strings.TrimPrefix(resourceAddress, fmt.Sprintf("module.%s.", resourceModuleName))
		var moduleCalls interface{}
		moduleCalls = rawPlan["configuration"].(map[string]interface{})["root_module"].(map[string]interface{})["module_calls"]
		if moduleCalls != nil {
			for module, value := range moduleCalls.(map[string]interface{}) {
				if module == resourceModuleName {
					resources = value.(map[string]interface{})["module"].(map[string]interface{})["resources"]
				}
			}
		} else {
			// all resourced inside the module have been removed
		}

	} else {
		resources = rawPlan["configuration"].(map[string]interface{})["root_module"].(map[string]interface{})["resources"]
	}
	// set default return value
	result = strings.Split(resourceAddress, "_")[0]
	if resources != nil {
		for i := range resources.([]interface{}) {
			address := resources.([]interface{})[i].(map[string]interface{})["address"].(string)
			if (address == resourceAddress) || (address == strings.Split(resourceAddress, "[")[0]) {
				result = resources.([]interface{})[i].(map[string]interface{})["provider_config_key"].(string)
				break
			}
		}
	}
	return result
}

/*
=============================================================
retruns account_id and region of a configured AWS provider named <targetProvider>
requires the following parameters are set in the provider configuration:
  - allowed_account_id (and set to only one account)
  - region
=============================================================
*/
func getProviderConfig(rawPlan map[string]interface{}, targetProvider string) ([]string, string) {
	if strings.Split(targetProvider, ".")[0] != "aws" {
		return []string{"N/A"}, "N/A"
	}
	var accounts []string
	var region string
	providerConfigs := rawPlan["configuration"].(map[string]interface{})["provider_config"].(map[string]interface{})
	for provider, value := range providerConfigs {
		if provider == targetProvider {
			accounts = interfaceListToStringList(value.(map[string]interface{})["expressions"].(map[string]interface{})["allowed_account_ids"].(map[string]interface{})["constant_value"].([]interface{}))
			// if len(accounts) != 1 {
			// 	log.Warn(fmt.Sprintf("Expecting only one account to be allowed: %v", accounts))
			// 	log.Warn(fmt.Sprintf("First allowed account is taken: %s", accounts[0]))
			// }
			// account = accounts[0]
			sort.Strings(accounts)
			// account = strings.Join(accounts, " ")
			region = value.(map[string]interface{})["expressions"].(map[string]interface{})["region"].(map[string]interface{})["constant_value"].(string)
			break
		}
	}
	return accounts, region
}

func getResourceChanges(rawPlan map[string]interface{}, componentPath string) ([]string, []string, []string, []string, []string) {
	resourcesToChangeArray := []string{}
	resourcesActionArray := []string{}
	resourcesToChangeInAccountArray := []string{}
	resourcesToChangeInRegionArray := []string{}
	resourcesToChangeInComponentArray := []string{}

	//Extract resource_changes block
	resourceChanges := rawPlan["resource_changes"]
	if resourceChanges != nil {
		// sortutil.AscByField(resourceChanges, "address") => FIXME: does not work!
		// Loop over the block and get the name, type and change fields from tf json plan file
		for i := range resourceChanges.([]interface{}) {
			resource := resourceChanges.([]interface{})[i].(map[string]interface{})["address"].(string)
			provider := getResourceProvider(rawPlan, resource)
			accounts, region := getProviderConfig(rawPlan, provider)
			strAccounts := fmt.Sprintf("%v", accounts)

			//Action performed on Resource to change
			change := resourceChanges.([]interface{})[i].(map[string]interface{})["change"]
			changeAction := change.(map[string]interface{})["actions"]
			strChangeAction := fmt.Sprintf("%v", changeAction)
			//Assign to Array
			resourcesToChangeArray = append(resourcesToChangeArray, resource)
			resourcesActionArray = append(resourcesActionArray, strChangeAction)
			// if strChangeAction == "[delete]" {
			// 	resourcesToChangeInAccountArray = append(resourcesToChangeInAccountArray, account)
			// } else {
			// 	resourcesToChangeInAccountArray = append(resourcesToChangeInAccountArray, account)
			// }
			resourcesToChangeInAccountArray = append(resourcesToChangeInAccountArray, strAccounts)
			resourcesToChangeInRegionArray = append(resourcesToChangeInRegionArray, region)
			resourcesToChangeInComponentArray = append(resourcesToChangeInComponentArray, componentPath)

		}
		//Return the Array
		return resourcesToChangeArray, resourcesActionArray, resourcesToChangeInAccountArray, resourcesToChangeInRegionArray, resourcesToChangeInComponentArray
	}
	return nil, nil, nil, nil, nil
}

/*
====================================
Function to find terraform plan file
====================================
*/
func findPlanFiles(dir string) []string {
	log := log.New(os.Stderr).WithColor()
	tfPlansLoc := []string{}
	regExpr, e := regexp.Compile("^tfplan+\\.(json)$") // find plan files of the form "tfplan.json"
	if e != nil {
		log.Fatal("Error finding plan file using regex", e)
	}
	e = filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err == nil && regExpr.MatchString(info.Name()) {
			tfPlansLoc = append(tfPlansLoc, path)
		}
		return nil
	})
	if e != nil {
		log.Fatal(e)
	}

	sort.Strings(tfPlansLoc)

	return tfPlansLoc
}

/*
==============================
Function to run shell commands
==============================
*/
func runShellCmd(wrkdir string, args ...string) {
	log := log.New(os.Stderr).WithColor()
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = wrkdir
	cmd.Env = os.Environ()
	// Silent terragrunt stdout and show only sterr if any
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("%s\n", out)
		log.Fatal("Error executing shell cmd:", err)
	}
}

/*
===================================
Function to find a string in array
==================================
*/
func findStrInArray(slice []string, strToSearch string) ([]string, bool) {
	for i := range slice {
		if slice[i] == strToSearch {
			return slice, true
		}
	}
	// slice = append(slice, strToSearch)
	return slice, false
}

func actionExists(action string, mapValue []resourceActions) (result bool) {
	result = false
	for _, value := range mapValue {
		if value.action == action {
			result = true
			break
		}
	}
	return result
}

func regionExists(region string, mapValue []resourceAccounts) (result bool) {
	result = false
	for _, value := range mapValue {
		if value.region == region {
			result = true
			break
		}
	}
	return result
}

func getSortedKeysResourceActionsArray(aMap map[string][]resourceActions) []string {
	keys := make([]string, 0, len(aMap))
	for key := range aMap {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func getSortedKeysResourceAccountsArray(aMap map[string][]resourceAccounts) []string {
	keys := make([]string, 0, len(aMap))
	for key := range aMap {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func sortResourceActionsArray(aMap map[string][]resourceActions) map[string][]resourceActions {
	result := make(map[string][]resourceActions, 0)
	keys := getSortedKeysResourceActionsArray(aMap)

	for _, key := range keys {
		result[key] = aMap[key]
	}

	for _, actionMaps := range result {
		sortutil.AscByField(actionMaps, "action")
		// for _, actionMap := range actionMaps {
		// 	sort.Strings(actionMap.components)
		// 	sort.Strings(actionMap.accounts)
		// 	sort.Strings(actionMap.regions)
		// }
	}

	return result
}

func sortResourceAccountsArray(aMap map[string][]resourceAccounts) map[string][]resourceAccounts {
	result := make(map[string][]resourceAccounts, 0)
	keys := getSortedKeysResourceAccountsArray(aMap)

	for _, key := range keys {
		result[key] = aMap[key]
	}

	for _, regionMaps := range result {
		sortutil.AscByField(regionMaps, "region")
		// for _, regionMap := range regionMaps {
		// 	sort.Strings(regionMap.components)
		// 	sort.Strings(regionMap.resources)
		// 	sort.Strings(regionMap.actions)
		// }
	}

	return result
}

/*
============================================
Main function
============================================
*/

func main() {
	log := log.New(os.Stderr).WithColor()
	flag.Parse()
	perComponentTable := string(*flagPerComponetTable)
	colorfullOutput := string(*flagColorfullOutput)
	hideReadOperations := string(*flaghideReadOperations)
	resourceMappedArray := make(map[string][]resourceActions)
	resourceMappedPerAccountArray := make(map[string][]resourceAccounts)

	plansDir := "../plans"
	tableRowCounter := 0

	/*
		=========================
		Find the tf json plan files
		==========================
	*/

	if colorfullOutput == "true" {
		printColored("\nTERRAFORM PLAN FILES")
	} else {
		fmt.Println("\nTERRAFORM PLAN FILES")
	}

	planFile := findPlanFiles(plansDir)
	/*
		==============================
		Terraform json planfile table
		==============================
	*/
	var colorGreen, colorYellow, colorRed []int
	if colorfullOutput == "true" {
		colorGreen = tablewriter.Colors{tablewriter.Bold, tablewriter.FgGreenColor}
		colorYellow = tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiYellowColor}
		colorRed = tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiRedColor}
	}

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"PLAN FILE", "NAMESPACE", "REGION", "ENVIRONMENT", "STACK", "COMPONENT"})
	table.SetHeaderColor(colorGreen, colorGreen, colorGreen, colorGreen, colorGreen, colorGreen)
	table.SetColumnColor(colorYellow, nil, nil, nil, nil, nil)

	tableRowCounter = 0
	for i := range planFile {
		tableRow := make([]string, 0)
		pathSplit := strings.Split(planFile[i], "/")
		namespace := pathSplit[2]
		region := pathSplit[3]
		environment := pathSplit[4]
		stack := pathSplit[5]
		component := pathSplit[6]
		tableRow = append(tableRow, planFile[i])
		tableRow = append(tableRow, namespace)
		tableRow = append(tableRow, region)
		tableRow = append(tableRow, environment)
		tableRow = append(tableRow, stack)
		tableRow = append(tableRow, component)
		// if component == "data" {
		// 	continue
		// }
		table.Append(tableRow)
		tableRowCounter++
	}

	if tableRowCounter == 0 {
		tableRow := []string{"N/A", "N/A", "N/A", "N/A", "N/A", "N/A"}
		table.Append(tableRow)
		table.SetFooter([]string{"NO PLAN FILE FOUND", "-", "-", "-", "-", "-"}) // Add Footer
		table.SetFooterColor(colorRed, nil, nil, nil, nil, nil)
	}
	fmt.Print("\n")
	table.Render()

	/*
		=============================================
		Read each plan file and show changes in table
		=============================================
	*/

	for i := range planFile {
		var rawPlan map[string]interface{}
		pathSplit := strings.Split(planFile[i], "/")
		namespace := pathSplit[2]
		region := pathSplit[3]
		environment := pathSplit[4]
		stack := pathSplit[5]
		component := pathSplit[6]
		componentPath := fmt.Sprintf("%s/%s/%s/%s/%s", namespace, region, environment, stack, component)
		jsonFile, err := ioutil.ReadFile(planFile[i])
		err = json.Unmarshal(jsonFile, &rawPlan)
		if err != nil {
			log.Fatal("Error parsing json plan: " + planFile[i] + " =>", err)
			return
		}

		// if component == "data" {
		// 	continue
		// }

		resourceChanges, resourceChangeActions, resourceChangedInAccounts, resourceChangedInRegions, resourceChangedInComponents := getResourceChanges(rawPlan, componentPath)
		// Populate the consolitdated resource changes array
		for i := range resourceChanges {
			resource := resourceChanges[i]
			action := resourceChangeActions[i]
			component := resourceChangedInComponents[i]
			account := resourceChangedInAccounts[i]
			region := resourceChangedInRegions[i]

			if actionMaps, ok := resourceMappedArray[resource]; ok {

				// check if the action is there in the array
				result := actionExists(action, actionMaps)
				if result == false {
					resourceMappedArray[resource] = append(resourceMappedArray[resource], resourceActions{action, []string{component}, []string{account}, []string{region}})
				} else {
					for j := range actionMaps {
						if action == actionMaps[j].action {
							actionMaps[j].accounts = append(actionMaps[j].accounts, account)
							actionMaps[j].regions = append(actionMaps[j].regions, region)
							actionMaps[j].components = append(actionMaps[j].components, component)
							break
						}
					}
				}
			} else {
				resourceMappedArray[resource] = append(resourceMappedArray[resource], resourceActions{action, []string{component}, []string{account}, []string{region}})
			}
		}

		if perComponentTable == "true" {
			if colorfullOutput == "true" {
				printColored(fmt.Sprintf("\nCOMPONENT CHANGES => %s", componentPath))
			} else {
				fmt.Println(fmt.Sprintf("\nCOMPONENT CHANGES => %s", componentPath))
			}

			table = tablewriter.NewWriter(os.Stdout)
			table.SetHeader([]string{"RESOURCE", "ACTION", "AWS ACCOUNT", "AWS REGION"})
			table.SetRowLine(true)
			table.SetHeaderColor(colorGreen, colorGreen, colorGreen, colorGreen)
			table.SetColumnColor(nil, nil, nil, nil)
			tableRowCounter = 0
			for i := range resourceChanges {
				if (resourceChangeActions[i] == "[no-op]") || (hideReadOperations == "true" && resourceChangeActions[i] == "[read]") {
					continue
				}
				tableRow := make([]string, 0)
				tableRow = append(tableRow, resourceChanges[i])
				tableRow = append(tableRow, resourceChangeActions[i])
				tableRow = append(tableRow, fmt.Sprintf("%v", resourceChangedInAccounts[i]))
				tableRow = append(tableRow, fmt.Sprintf("%v", resourceChangedInRegions[i]))
				table.Append(tableRow)
				tableRowCounter++

			}

			if tableRowCounter == 0 {
				tableRow := []string{"N/A", "N/A", "N/A", "N/A"}
				table.Append(tableRow)
				table.SetFooter([]string{"-", "NO CHANGES", "-", "-"}) // Add Footer
				table.SetFooterColor(nil, colorRed, nil, nil)
			}
			table.SetAutoMergeCells(true)
			fmt.Print("\n")
			table.Render()

		}
	}

	// spew.Dump(resourceMappedArray)
	resourceMappedArray = sortResourceActionsArray(resourceMappedArray)
	// spew.Dump(resourceMappedArray)

	// Populate the consolidated resource changes per consolidated accounts array
	//	for resource, actionMaps := range resourceMappedArray {
	// WORKAROUND => eventhough resourceMappedArray is sorted by key, the for loop does not retrieve them by order!
	resources := getSortedKeysResourceActionsArray(resourceMappedArray)
	for _, resource := range resources {
		actionMaps := resourceMappedArray[resource]
		for i := range actionMaps {
			action := actionMaps[i].action
			if (action == "[no-op]") || (hideReadOperations == "true" && action == "[read]") {
				continue
			}
			for j := range actionMaps[i].accounts {
				account := actionMaps[i].accounts[j]
				region := actionMaps[i].regions[j]
				component := actionMaps[i].components[j]
				if regionMaps, found := resourceMappedPerAccountArray[account]; found {
					// check if the region is there in the array
					result := regionExists(region, regionMaps)
					if result == false {
						resourceMappedPerAccountArray[account] = append(resourceMappedPerAccountArray[account], resourceAccounts{region, []string{component}, []string{resource}, []string{action}})
					} else {
						for k := range regionMaps {
							if regionMaps[k].region == region {
								regionMaps[k].components = append(regionMaps[k].components, component)
								regionMaps[k].resources = append(regionMaps[k].resources, resource)
								regionMaps[k].actions = append(regionMaps[k].actions, action)
								break
							}
						}
					}
				} else {
					resourceMappedPerAccountArray[account] = append(resourceMappedPerAccountArray[account], resourceAccounts{region, []string{component}, []string{resource}, []string{action}})
				}
			}
		}
	}

	resourceMappedPerAccountArray = sortResourceAccountsArray(resourceMappedPerAccountArray)

	// Show consolidated table of changes
	if colorfullOutput == "true" {
		printColored("\nCONSOLIDATED CHANGES PER RESOURCE/ACTION")
	} else {
		fmt.Println("\nCONSOLIDATED CHANGES PER RESOURCE/ACTION")
	}

	table = tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"RESOURCE", "ACTION", "COMPONENT", "AWS ACCOUNT", "AWS REGION"})
	table.SetRowLine(true)
	table.SetHeaderColor(colorGreen, colorGreen, colorGreen, colorGreen, colorGreen)
	table.SetColumnColor(colorYellow, nil, nil, nil, nil)

	tableRowCounter = 0
	//for resource, actionMaps := range resourceMappedArray {
	// WORKAROUND => eventhough resourceMappedArray is sorted by key, the for loop does not retrieve them by order!
	resources = getSortedKeysResourceActionsArray(resourceMappedArray)
	for _, resource := range resources {
		actionMaps := resourceMappedArray[resource]
		for i := range actionMaps {
			if (actionMaps[i].action == "[no-op]") || (hideReadOperations == "true" && actionMaps[i].action == "[read]") {
				continue
			}
			tableRow := make([]string, 0)
			tableRow = append(tableRow, resource)
			tableRow = append(tableRow, actionMaps[i].action)
			tableRow = append(tableRow, strings.Join(actionMaps[i].components, "\n"))
			tableRow = append(tableRow, strings.Join(actionMaps[i].accounts, "\n"))
			tableRow = append(tableRow, strings.Join(actionMaps[i].regions, "\n"))
			table.Append(tableRow)
			tableRowCounter++
		}
	}

	if tableRowCounter == 0 {
		tableRow := []string{"N/A", "N/A", "N/A", "N/A", "N/A"}
		table.Append(tableRow)
		table.SetFooter([]string{"-", "NO CHANGES", "-", "-", "-"}) // Add Footer
		table.SetFooterColor(nil, colorRed, nil, nil, nil)
	}
	table.SetAutoMergeCells(true)
	fmt.Print("\n")
	table.Render()

	// Show consolidated table of changes per consolidated account
	if colorfullOutput == "true" {
		printColored("\nCONSOLIDATED CHANGES PER ACCOUNT/REGION")
	} else {
		fmt.Println("\nCONSOLIDATED CHANGES PER ACCOUNT/REGION")
	}
	table = tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"AWS ACCOUNT", "AWS REGION", "COMPONENT", "RESOURCE", "ACTION"})
	table.SetRowLine(true)
	table.SetHeaderColor(colorGreen, colorGreen, colorGreen, colorGreen, colorGreen)
	table.SetColumnColor(colorYellow, nil, nil, nil, nil)

	// spew.Dump(resourceMappedPerAccountArray)

	tableRowCounter = 0
	// for account, regionMaps := range resourceMappedPerAccountArray {
	// WORKAROUND => eventhough resourceMappedPerAccountArray is sorted by key, the for loop does not retrieve them by order!
	accounts := getSortedKeysResourceAccountsArray(resourceMappedPerAccountArray)
	for _, account := range accounts {
		regionMaps := resourceMappedPerAccountArray[account]
		for i := range regionMaps {
			if (fmt.Sprintf("%v", regionMaps[i].actions) == "[no-op]") || (hideReadOperations == "true" && fmt.Sprintf("%v", regionMaps[i].actions) == "[read]") {
				continue
			}
			tableRow := make([]string, 0)
			tableRow = append(tableRow, account)
			tableRow = append(tableRow, regionMaps[i].region)
			tableRow = append(tableRow, strings.Join(regionMaps[i].components, "\n"))
			tableRow = append(tableRow, strings.Join(regionMaps[i].resources, "\n"))
			tableRow = append(tableRow, strings.Join(regionMaps[i].actions, "\n"))
			table.Append(tableRow)
			tableRowCounter++
		}
	}

	if tableRowCounter == 0 {
		tableRow := []string{"N/A", "N/A", "N/A", "N/A", "N/A"}
		table.Append(tableRow)
		table.SetFooter([]string{"-", "-", "-", "-", "NO CHANGES"}) // Add Footer
		table.SetFooterColor(nil, nil, nil, nil, colorRed)
	}
	table.SetAutoMergeCells(true)
	// table.SetAutoWrapText(true)
	fmt.Print("\n")
	table.Render()

}
