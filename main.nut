import("pathfinder.road", "RoadPathFinder", 3);





/*--------------------------------------------------------------------
|                                                                     |
|    Tile                                                             |
|                                                                     |
 --------------------------------------------------------------------*/
class Tile
{
	constructor() {
		
	}
	function GetAdjacentTiles(tile);
	function IsRoadBuildable(tile);  // used for valuator
}	

function Tile::GetAdjacentTiles(tile)
{
	local adjTiles = AITileList();
	
	adjTiles.AddTile(tile - AIMap.GetTileIndex(1,0));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(0,1));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(-1,0));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(0,-1));
	
	return adjTiles;
}

function Tile::IsRoadBuildable(tile)
{
	if (AITile.IsBuildable(tile) || AIRoad.IsRoadTile(tile)) return true;
	return false;
}


/*--------------------------------------------------------------------
|                                                                     |
|    TownManager                                                      |
|                                                                     |
 --------------------------------------------------------------------*/
class TownManager
{
	constructor() {

	}
	function CreateExitRoute(busstop, town1);
	function BuildBusStop(tile);
	function FindLineBusStopLocation(town, pass_cargo_id, estimate);
	function EstimateAcceptance(town);
}

/*------------------------------------------------------------------*/
function TownManager::CreateExitRoute(busstop, town1) 
{
	local rtl = AITileList();
				
	rtl.Clear();
	rtl.AddRectangle(busstop + AIMap.GetTileIndex(-5,-5), busstop + AIMap.GetTileIndex(5,5));
	rtl.Valuate(Tile.IsRoadBuildable);
	rtl.KeepValue(1);
	rtl.Valuate(AITile.GetSlope);
	rtl.KeepValue(0);
	
	rtl.Valuate(AITile.GetDistanceManhattanToTile, AITown.GetLocation(town1));
	rtl.KeepBottom(1);
	local town_exit0 = rtl.Begin();
	return town_exit0;

}

/*------------------------------------------------------------------*/
function TownManager::FindLineBusStopLocation(town, pass_cargo_id, estimate)
{
	local tl = AITileList();
	local aitile = null;
	local tile = AITown.GetLocation(town);
	local found = false;
	local ret_tile = null;
	
	tl.AddRectangle(tile + AIMap.GetTileIndex(-8, -8), tile + AIMap.GetTileIndex(8, 8));
	
	/* remove all tiles that are already covered by a station */
	local tl2 = AITileList();

	tl2.AddList(tl);
	tl2.Valuate(AIRoad.IsRoadStationTile);
	tl2.KeepValue(1);

	for (local rstl = tl2.Begin(); tl2.HasNext() ; rstl = tl2.Next()){
		/* Keep our own stations a bit apart */
		if (AITile.GetOwner(rstl) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) {
			tl.RemoveRectangle(rstl + AIMap.GetTileIndex(-4, -4), rstl + AIMap.GetTileIndex(4, 4));
		}
		else {    /* but don't be so modest with other players stations ... */
			tl.RemoveRectangle(rstl + AIMap.GetTileIndex(-1, -1), rstl + AIMap.GetTileIndex(1, 1));
		}
	}	 

	if (tl.Count()) {
		/* find all tiles that are next to a road tile */
		tl.Valuate(AIRoad.GetNeighbourRoadCount);	
		tl.KeepAboveValue(0);

		if (tl.Count()) {
			/* find all tiles that are not road */
	   	tl.Valuate(AIRoad.IsRoadTile);	
   	  	tl.KeepValue(0);
			if (tl.Count()) {
	   		/* find all tiles that are not sloped */
		   	tl.Valuate(AITile.GetSlope);	
   		   tl.KeepValue(0);
				if (tl.Count()) {
					tl.Valuate(AITile.GetCargoAcceptance, pass_cargo_id,
								 1, 1, 
								 AIStation.GetCoverageRadius (AIStation.STATION_BUS_STOP));
					for (aitile = tl.Begin(); tl.HasNext(); aitile = tl.Next()){
//						AISign.BuildSign(aitile,"ex"+tl.GetValue(aitile));
						if (tl.GetValue(aitile) >= 15){
  							found = AITile.IsBuildable(aitile);
							if (estimate) {
								found = true;
							}	
							if (!found)	{
								found = AITile.DemolishTile(aitile);
							}
							if (found) {
								ret_tile = aitile;
								break;
							}	
						}	
//						else {
//							AILog.Info("Find busstop location, acceptance too low " + tl.GetValue(aitile));
//						}
	   			}
				}
				else {
					AILog.Info("Find busstop location, no unsloped tiles present");
				}
	   	}
			else {
				AILog.Info("Find busstop location, no tiles that are not road present");
			}
	   }
		else {
			AILog.Info("Find busstop location, no tiles next to road present");
		}
	}
	

	
	if (found) {
//		AISign.BuildSign(aitile,"ex"+tl.GetValue(aitile));
		return ret_tile;	
	}	
	else {
		return null;	
	}	
}



/*------------------------------------------------------------------*/
function TownManager::BuildBusStop(tile)
{
	local found = false;
	local success = false;

	local adjacentTiles = Tile.GetAdjacentTiles(tile);

	for(local tile2 = adjacentTiles.Begin(); 
			adjacentTiles.HasNext() && !found; 
			tile2 = adjacentTiles.Next()) {
		if(AIRoad.IsRoadTile(tile2) ) {
			local count = 0;
			success = true;
			local truck = AIRoad.ROADVEHTYPE_BUS; 
			local adjacent = AIStation.STATION_NEW;
			if (success) {
				success = AIRoad.BuildRoadStation(tile, tile2, truck, adjacent);
			}
			found = true;
		}
	}

	if (!success) {
		AILog.Info("Build busstop failed "+ AIError.GetLastErrorString());
//		AISign.BuildSign(tile,"bbs");
	}
	return success;	
}

/*------------------------------------------------------------------*/
function TownManager::EstimateAcceptance(town, passenger_cargo_id)
{
	local new_location = TownManager.FindLineBusStopLocation(town,
																passenger_cargo_id, true);
		
	local acceptance = 0;
	if (new_location){

		acceptance = AITile.GetCargoAcceptance(new_location, passenger_cargo_id, 1, 1, 
													 AIStation.GetCoverageRadius (AIStation.STATION_BUS_STOP));					

	}												 
	return acceptance;											 

}


/*--------------------------------------------------------------------
|                                                                     |
|    RoutePlanner                                                     |
|                                                                     |
 --------------------------------------------------------------------*/
class RoutePlanner
{
	town_list             = null;
	town_list2            = null;
	town_acc_list         = null;
	state                 = 0;
	cargo_id              = 0;
	date_town_acc_update  = 0;
	constructor(pass_cargo_id) {
		this.cargo_id      = pass_cargo_id;
		this.town_list     = null;
		this.town_list2    = null;
		this.town_acc_list = null;
		this.state         = 0;
		date_town_acc_update  = 0;
	}
	function FindUnusedTowns(agressive);
	function InitTownList();
	function UpdateTownAcceptanceList();
}


/*------------------------------------------------------------------*/
function RoutePlanner::InitTownList()
{
   this.town_list2 = AITownList(); 
	this.town_list  = AIList();
	this.town_list.AddList(this.town_list2);
	town_list.Valuate(AITown.GetPopulation);
	this.town_acc_list = AIList();
	UpdateTownAcceptanceList();
}


/*------------------------------------------------------------------*/
function RoutePlanner::UpdateTownAcceptanceList()
{

	if (AIDate.GetCurrentDate() - date_town_acc_update > 60)	{
		town_acc_list.Clear();
		foreach ( twn, v in town_list){
			local acc = TownManager.EstimateAcceptance(twn, cargo_id);
			town_acc_list.AddItem(twn, acc);
		 	AIController.Sleep(1);
		}
		date_town_acc_update = AIDate.GetCurrentDate();
	}
}


/*------------------------------------------------------------------*/
function RoutePlanner::FindUnusedTowns(agressive)
{


	local town    = 0;
	local town2   = 0;
	local town_it = AITown();
	local found   = false;

//	AILog.Info("Find unused towns agressive: " + agressive);
	switch (state) {
		case	0:	
			AILog.Info("Find unused towns, state 0");

			UpdateTownAcceptanceList();			
			if (town_acc_list.Count()){
				for (town_it = town_acc_list.Begin(); town_acc_list.HasNext(); 
	  				town_it = town_acc_list.Next()){
					AILog.Info("acceptance of " + AITown.GetName(town_it) + " = " + town_acc_list.GetValue(town_it));					
					local tl2 = AITileList();
					/* On agressive setting, build wherever you can to make money, 
					 * On not-agressive setting, keep away from the towns where a player already built a station
					 */   
					if (!agressive){
						tl2.AddRectangle(AITown.GetLocation(town_it) + AIMap.GetTileIndex(-8, -8),
		 			   					  AITown.GetLocation(town_it) + AIMap.GetTileIndex(8, 8));
						tl2.Valuate(AIRoad.IsRoadStationTile);
						tl2.KeepValue(1);
					}	
					if (!tl2.Count()){
						town = town_it;
						found = true;
						town_acc_list.RemoveItem(town);
						break;
					}
				}	

				if (found) {
					found = false;
//					AILog.Info("Find unused towns, find second town");
					town_list2.Clear();
					town_list2.AddList(town_list);
					town_list2.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
					town_list2.KeepBetweenValue(70,140);
					if (!town_list2.Count()){
						town_list2.AddList(town_list);
					}
					local town_list3 = AIList();

					foreach ( twn, v in town_list2){
						local acc = TownManager.EstimateAcceptance(twn, cargo_id);
						town_list3.AddItem(twn, acc);
						AIController.Sleep(1);
					}
					if (town_list3.Count()) {
						for (town_it = town_list3.Begin(); town_list3.HasNext(); 
	   						town_it = town_list3.Next()){
							if (town_it != town) {	
								local tl2 = AITileList();
								/* On agressive setting, build wherever you can to make money, 
								 * On not-agressive setting, keep away from the towns where a player already built a station	
								 */   
								if (!agressive){
									tl2.AddRectangle(	AITown.GetLocation(town_it) + AIMap.GetTileIndex(-8, -8),
															AITown.GetLocation(town_it) + AIMap.GetTileIndex(8, 8));
									tl2.Valuate(AIRoad.IsRoadStationTile);
									tl2.KeepValue(1);
								}
								if (!tl2.Count()){
									town2 = town_it;
									found = true;
									break;
								}
								else {
									found = false;
									AILog.Info("Find unused towns, find second town: not found");
								}
							}
						}
					}
				}		
			}
			else {
				state = 1;
				return null;
			}	
		break;
		case 1:
			break; 
	}
	if (found) {
		return [ town, town2 ];
	}
	else {
		return null;
	}
}

/*--------------------------------------------------------------------
|                                                                     |
|    Line                                                             |
|                                                                     |
 --------------------------------------------------------------------*/

class Line
{
	towns    = null;
	stations = null;
	depot    = null;
	vehicles = null;
	date_last_vehicle = 0;
	failed = false;
	passenger_cargo_id = 0;
	pending_vehicles = 0;
	new_location = null;	
	try_rebuild = false;
	town_exit = null;
	n_buses = 0;
	constructor(cargo_id) {
		towns     = [];
		stations = [[], []];
		depot    = null;
		vehicles  = [];
		failed = false;
		date_last_vehicle = 0;
		passenger_cargo_id = cargo_id;
		new_location = [0,0];
		pending_vehicles = 0;
		try_rebuild = false;
		town_exit = [0, 0];
		n_buses = 0;
	}
	function AddVehicles();
	function EstimateBusesNeeded(station0, station1);
	function AddDepot();
	function CreateNewLine(town_pair);
}


function Line::CreateNewLine(town_pair)
{
	local connected = false;

	local success   = [false, false];
	local newline   = (town_pair != null);

	if (town_pair) {
		local town_idx     = 0;

		foreach (town in town_pair){
			new_location[town_idx] = TownManager.FindLineBusStopLocation(town, passenger_cargo_id, false);
			town_idx++;															
		}
		towns = town_pair;
	}
	if(towns && (towns.len() == 2))
	{
		AILog.Info("New line from: " + AITown.GetName(towns[0]) + " to " + AITown.GetName(towns[1]));

		local town_idx     = 0;
		local station_idx  = 0;

		if (!try_rebuild) {
			foreach (town in towns){
				if (new_location[0] && new_location[1]){
					stations[town_idx].append (new_location[town_idx]);				
					success[town_idx] = TownManager.BuildBusStop(new_location[town_idx]);
					if (success[town_idx]) {
						AILog.Info("busstop " + town_idx + " built");
						town_exit[town_idx] =  TownManager.CreateExitRoute(AIRoad.GetRoadStationFrontTile(new_location[town_idx]), towns[(town_idx+1) %2 ]);
						if (!town_exit[town_idx]) {
							success[town_idx] = false;
							AILog.Info("Create exit " + town_idx + " failed");
							break;
						}					
					}
				}	
				else {
						AILog.Info("New line: no locations present");
					break;
				}
				town_idx++;
			}
					
			// Build depot

			if((success[0] == false) || (success[1] == false)) {
				AILog.Info("Failed to build bus stations");
			}
			else {
				if (newline) {
					depot = AddDepot(stations[0][0]);
					if (depot) {
						AILog.Info("Depot built " + depot);
						connected = true;
					}
					else {
						AILog.Info("Failed to build depot");
					}
				}
				else {
					connected = true;
				}
			}
		}
		else {
			AILog.Info("CreateNewLine: try rebuild");
			connected = true;
			try_rebuild = false;
			newline = true;
		} 
	}	
	else {
		AILog.Info("no 2 towns to connect");
	}
	return connected;
}

/*------------------------------------------------------------------*/
function Line::AddVehicles()
{
	if(this.stations[0].len() != this.stations[1].len()) {
		AILog.Info("AddVehicles nof stations incorrect");
		return null;
	}
	local bus_model = null;
	local min_reliability = 85;
	local new_bus;
	local i;

	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
	
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.KeepBelowValue(balance);

	engine_list.Valuate(AIEngine.GetCargoType)
	engine_list.KeepValue(passenger_cargo_id); 

	engine_list.Valuate(AIEngine.GetCapacity)
	engine_list.KeepTop(1);
	
	if ( n_buses == 0 ) {	
		n_buses = EstimateBusesNeeded(this.stations[0][this.stations[0].len()-1],
											   this.stations[1][this.stations[1].len()-1]);
	}
	else {
		AILog.Info("Add vehicles: retry to add buses to the line" + n_buses);
	}
	if (!engine_list.Count()) {
		AILog.Info("BuyBuses: failed to find a bus to build");
		return false;
	}

	bus_model = engine_list.Begin();

	// Buy buses
	local buses_build = 0;
	for(i = 0; i < n_buses; ++i)
	{
		new_bus = AIVehicle.BuildVehicle(this.depot, bus_model);
		local er = AIError.GetLastError();
		if (AIVehicle.IsValidVehicle(new_bus)) { 
			this.vehicles.append(new_bus);
			buses_build = buses_build + 1;
		}
		else {
			if (er != AIError.ERR_NOT_ENOUGH_CASH) {
				n_buses = n_buses - 1; // prevent endless retries
			}
			AILog.Info("Buy vehicles failed "+ AIError.GetLastErrorString() + " " + this.depot);
		}
	}
	n_buses = n_buses - buses_build;
	pending_vehicles = pending_vehicles + buses_build;
	AILog.Info("Buses build pending:" + pending_vehicles);
	local idx0 = 0;
	local idx1 = 1;	
	local town_idx = 0;	
	local buses_started = 0;
	for (local bus_idx = this.vehicles.len() - buses_build; bus_idx < this.vehicles.len(); bus_idx++){
		local bus = this.vehicles[bus_idx]; 

		if(bus == null || !AIVehicle.IsValidVehicle(bus)) {
			AILog.Info("Vehicle[ " + bus + "] is not valid!");
		}	
		else {
			idx0 = this.stations[town_idx].len()-1;
			AIOrder.AppendOrder(bus, this.depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
			AIOrder.AppendOrder(bus, this.stations[town_idx][idx0], AIOrder.AIOF_NONE); 
			town_idx = (town_idx + 1) % 2;
			idx1 = this.stations[town_idx].len()-1;
			AIOrder.AppendOrder(bus, this.stations[town_idx][idx1], AIOrder.AIOF_NONE);
			/* don't increment town_idx here, so orders are alternating: half the buses
			 * to 1 town, the others to the other town */
			 
		}
	}	
}

/*------------------------------------------------------------------*/
function Line::EstimateBusesNeeded(station0, station1)
{

	if(!station0 || !station1)
		return 0;
	
	local acceptance = AITile.GetCargoAcceptance(station0, 
																passenger_cargo_id, 1, 1, 
																AIStation.GetCoverageRadius (AIStation.STATION_BUS_STOP)) + 
							AITile.GetCargoAcceptance(station1, 
																passenger_cargo_id, 1, 1, 
							AIStation.GetCoverageRadius (AIStation.STATION_BUS_STOP)) ;
	local distance = AIMap.DistanceManhattan( station0, station1 );

	AILog.Info("EstimateBusesNeeded: distance:    " + distance + 
	 										 " acceptance:  " + acceptance);

	local num_bus = 2 + (acceptance / 35) * (distance / 35);
	
	if (num_bus > 25) num_bus = 25;
	AILog.Info("Buy " + num_bus + " buses");
	return num_bus;
}


/*------------------------------------------------------------------*/
function Line::AddDepot(tile)
{
	local tl     = AITileList();
	local x      = AIMap.GetTileX(tile);
	local y      = AIMap.GetTileY(tile);
	local aitile = 0;
	local found  = false;
	
	tl.AddRectangle(AIMap.GetTileIndex(x-10,y-10), AIMap.GetTileIndex(x+10,y+10));
	if (tl.Count())
	{
	   if (tl.Count()) {
	   	/* find all tiles that are next to a road tile */

	   	tl.Valuate(AIRoad.GetNeighbourRoadCount);	
   	   	tl.KeepAboveValue(0);
	   }
	   if (tl.Count()) {
	   	/* find all tiles that are not road */
	   	tl.Valuate(AIRoad.IsRoadTile);	
   	  	tl.KeepValue(0);
	   }
	   if (tl.Count()) {
	   	/* find all tiles that are not sloped */

	   	tl.Valuate(AITile.GetSlope);	
   	   tl.KeepValue(0);
	   }
   	if (tl.Count()) {
			tl.Valuate(AITile.GetDistanceManhattanToTile, AITown.GetLocation(towns[1]));
			tl.Sort(AITileList.SORT_BY_VALUE, true);
		
			for (aitile = tl.Begin();tl.HasNext() && !found; 
			    aitile = tl.Next()) {    
				local adjacentTiles = Tile.GetAdjacentTiles(aitile);

				/*Loop through all adjacent tiles*/

				for(local tile2 = adjacentTiles.Begin(); 
			   	 adjacentTiles.HasNext() && !found; 
			    	 tile2 = adjacentTiles.Next()) {
			   	if(AIRoad.IsRoadTile(tile2) && !AITile.GetSlope(tile2) ) {
						if (!AIRoad.IsRoadTile(tile2+tile2-aitile)) {
							if(!AIRoad.IsRoadStationTile(aitile)) {
				   			found = AITile.IsBuildable(aitile);
								if (!found)	{
									found = AITile.DemolishTile(aitile);
								}	
								if (found) {
									AIRoad.BuildRoad(tile2, aitile);
									found = AIRoad.BuildRoadDepot(aitile, tile2)
								}
							}
						}
					}
		   	}
				if (found) {
			   	break;
				}
			}
	   }
	}
	if (found) {
		return aitile;	
	}
	else {
		return null;
	}
}



/*--------------------------------------------------------------------
|                                                                     |
|    rocketAI                                                         |
|                                                                     |
 --------------------------------------------------------------------*/

 
 class rocketAI extends AIController {
passenger_cargo_id = 0;
route_planner      = null;
stop               = false;
company            = null;
agressive		   = true;
lines              = [];
}
 
 
 
function rocketAI::Start()
{
	
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
	
	
	
  /* Get a list of all towns on the map. */
  local townlist = AITownList();
  /* Sort the list by population, highest population first. */
  townlist.Valuate(AITown.GetPopulation);
  townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
  /* Pick the two towns with the highest population. */
  local townid_a = townlist.Begin();
  
  
  
  /* Bygger vei fra den største byen til de 5 neste byene på by-lista. */
  
  for( local k = 1; k<=2; k++ ) {
  local townid_b = townlist.Next();
  /* Print the names of the towns we'll try to connect. */
  AILog.Info("Going to connect " + AITown.GetName(townid_a) + " to " + AITown.GetName(townid_b));

  /* Tell OpenTTD we want to build normal road (no tram tracks). */
  AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
  /* Create an instance of the pathfinder. */
  local pathfinder = RoadPathFinder();
  /* Set the cost for making a turn extreme high. */
  pathfinder.cost.turn = 1;
  /* Give the source and goal tiles to the pathfinder. */
  pathfinder.InitializePath([AITown.GetLocation(townid_a)], [AITown.GetLocation(townid_b)]);

  /* Try to find a path. */
  local path = false;
  while (path == false) {
    path = pathfinder.FindPath(100);
    this.Sleep(1);
  }

  if (path == null) {
    /* No path was found. */
    AILog.Error("pathfinder.FindPath return null");
  }

  /* If a path was found, build a road over it. */
  while (path != null) {
    local par = path.GetParent();
    if (par != null) {
      local last_node = path.GetTile();
      if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
        if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
          /* An error occured while building a piece of road. TODO: handle it. 
           * Note that is can also be the case that the road was already build. */
        }
      } else {
        /* Build a bridge or tunnel. */
        if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
          /* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
          if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
          if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
            if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
              /* An error occured while building a tunnel. TODO: handle it. */
            }
          } else {
            local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
            bridge_list.Valuate(AIBridge.GetMaxSpeed);
            bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
            if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
              /* An error occured while building a bridge. TODO: handle it. */
            }
          }
        }
      }
    }
    path = par;
  }
  }
  /* Ferdig med å lage byer. */
  AILog.Info("Ferdig med å lage byer");
  
  
  
  local cargo_list = AICargoList();
  
  cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
	if (cargo_list.Count() == 0) {
	/* There is no passenger cargo, so adding buses is useless. */
		this.passenger_cargo_id = null;
		return;
	}
	if (cargo_list.Count() > 1) {
		local town_list = AITownList();
		town_list.Valuate(AITown.GetPopulation);
		town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		local best_cargo = null;
		local best_cargo_acceptance = 0;
		foreach (cargo, dummy in cargo_list) {
			local acceptance = AITile.GetCargoAcceptance(AITown.GetLocation(town_list.Begin()), cargo, 1, 1, 5);
			if (acceptance > best_cargo_acceptance) {
				best_cargo_acceptance = acceptance;
				best_cargo = cargo;
			}
		}
		this.passenger_cargo_id = best_cargo;
	} else {
		this.passenger_cargo_id = cargo_list.Begin();
	}

	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);
	
	if (engine_list.Count() == 0) {
		AILog.Info("Stopping because no road passenger vehicles are available");
		return;
	}
	route_planner = RoutePlanner(this.passenger_cargo_id);
	route_planner.InitTownList();
	
	local i = 0;
	while(!this.stop)
	{
		this.Sleep(1);

		if((i%200)==1)
		{
			ManageVehicles();
		}	
		// ... check if we can afford to build some stuff
		if((i%50)==0) {
			local iters = 0;
			while (iters < 20) {
				ManageVehicles();
				AILog.Info("Start building");		
				iters = iters + 1;
				local line      = null;
				local connected = false;
				local est_acceptance = 0;
				local connect_new_town = true;
				local retried = false;
				
				foreach ( line_it in lines) {
					if (line_it.try_rebuild) {
						AILog.Info("Try rebuild");					
						connected = line_it.CreateNewLine(null);
						if(connected) {	
							AILog.Info("Retry build line completed");
							line_it.AddVehicles(); 
						}
						retried = true;
						break;
					}
					if (!line_it.try_rebuild) {
						if (line_it.n_buses) {
							line_it.AddVehicles(); 
							retried = true;
						}
					}
				}
				if ( retried) { 
					retried = false;
				} 
				else {

					local towns; 
					if (agressive) {
						towns = this.route_planner.FindUnusedTowns(true);
					}
					else {
						towns	= this.route_planner.FindUnusedTowns(false);
					}
					if(towns && (towns.len() == 2)) {
						line = Line(this.passenger_cargo_id);
					}
					else iters = 20;  // no new towns found, stop looping
					
					if(towns && (towns.len() == 2)) {
						local conn = line.CreateNewLine(towns);
						if(conn) {	
							AILog.Info("New line completed");
							line.AddVehicles(); 
							lines.append(line);
						}
						else {
							if (line.try_rebuild) {
								lines.append(line);
							}
							AILog.Info("Failed to add new line");
						}
					}
				}
				this.Sleep(1);
			}
			
		}
		i++;
	}	
 
  
  
  
}




/*------------------------------------------------------------------*/
function rocketAI::ManageVehicles()
{
	local list = AIVehicleList();
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(700);
	list.Valuate(AIVehicle.GetProfitLastYear);
   
	for (local i = list.Begin(); list.HasNext(); i = list.Next()) {
		local profit = list.GetValue(i);

		if (profit < -100) {
			local station_lst = AIStationList_Vehicle(i);
			local station0 = null;
			local station1 = null;
			if (station_lst) {
				station0 = station_lst.Begin(); 
				
				if (station_lst.HasNext()){
					station1 = station_lst.Next();
				}
			}	
			if (station0 && station1) {
				local rating_st0 = AIStation.GetCargoRating(station0, passenger_cargo_id);
				local rating_st1 = AIStation.GetCargoRating(station1, passenger_cargo_id);			
				if ((rating_st0 >= 40) && (rating_st1 >= 40)){
					/* Send the vehicle to depot if we didn't do so yet */
					if (!this.vehicle_to_depot.rawin(i) || this.vehicle_to_depot.rawget(i) != true) {
						AILog.Info(this.name + ": [INFO] Sending " + i + " to depot as	profit is: " + profit );
						AIVehicle.SendVehicleToDepot(i);
						this.vehicle_to_depot.rawset(i, true);
					}
				}
			}	
		}
		/* Try to sell it over and over till it really is in the depot */
		if (this.vehicle_to_depot.rawin(i) && this.vehicle_to_depot.rawget(i) == true) {
			if (AIVehicle.SellVehicle(i)) {
				AILog.Info(this.name + ": [INFO] Selling " + i + " as it finally is in a depot.");

				this.vehicle_to_depot.rawdelete(i);
			}
		}
	}

	foreach (line_it in lines) {
		if (line_it.pending_vehicles) {
//			AILog.Info(this.name + ": [INFO] pending vehicles" + line_it.pending_vehicles);
			if ((AIDate.GetCurrentDate() - line_it.date_last_vehicle) > 10){
				line_it.date_last_vehicle = AIDate.GetCurrentDate();
				
				local veh_to_start = line_it.vehicles[line_it.vehicles.len() - line_it.pending_vehicles];
				AIVehicle.StartStopVehicle(veh_to_start);

				line_it.pending_vehicles = line_it.pending_vehicles - 1;
//				AILog.Info(this.name + ": [INFO] pending vehicle started" + line_it.pending_vehicles);
				
				if ( line_it.pending_vehicles ){
					veh_to_start = line_it.vehicles[line_it.vehicles.len() - line_it.pending_vehicles];
					AIVehicle.StartStopVehicle(veh_to_start);
					line_it.pending_vehicles = line_it.pending_vehicles - 1;
//					AILog.Info(this.name + ": [INFO] pending vehicle started" + line_it.pending_vehicles);
				}
			}
		}
	}
	foreach (line_it in lines) {
		foreach (station in line_it.stations[0]){
			local curr_station = AIStation.GetStationID(station);
			local veh_list_station = AIVehicleList_Station(curr_station);
			
			if (veh_list_station.Count() < 35) {
				local second_station = AIStationList_Vehicle(veh_list_station.Begin()).Begin();
				local waiting = AIStation.GetCargoWaiting(curr_station,
																		passenger_cargo_id) +
	   				AIStation.GetCargoWaiting(AIStation.GetStationID(second_station),
																		passenger_cargo_id);
				local rating0 = AIStation.GetCargoRating(curr_station, passenger_cargo_id);
				local rating1 = AIStation.GetCargoRating(second_station, passenger_cargo_id);
//				AILog.Info(this.name + ": [INFO] wait "+ waiting + "ratings "+ rating0 + " " + rating1);	
				if ((waiting > 45) && ((rating0 < 75) || (rating1 < 75))) {
					if (AIDate.GetCurrentDate() - line_it.date_last_vehicle > 50) {
						if (veh_list_station.Begin() && line_it.depot) {
							for(local i = 0; i < (waiting / 45); ++i) {
								local new_veh = AIVehicle.CloneVehicle (line_it.depot, 
																		veh_list_station.Begin(), true);			
								line_it.vehicles.append(new_veh);				
								line_it.pending_vehicles = line_it.pending_vehicles + 1;
//								line_it.date_last_vehicle = AIDate.GetCurrentDate();
								AILog.Info("Manage vehicles: cloned veh " + line_it.pending_vehicles);
							}
						}
					}
				}
			}
		}
	}
}
