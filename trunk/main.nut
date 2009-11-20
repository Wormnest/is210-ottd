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
|   PathFinder                                                        |
|                                                                     |
 --------------------------------------------------------------------*/
class PathFinder
{
	err = 0;
	constructor() {
		err = AIError.ERR_NONE;
	}
	function BuildRoad(tile1, tile2);
}

/*------------------------------------------------------------------*/
function PathFinder::BuildRoad(start, target)
{
	local retry_find   = false;	
	local plan_retries = 0;
	local pathfinder = RoadPathFinder();
	local path_len = 0;	

	if(start == null || target == null )	{
		AILog.Info("PathFinder: BuildRoad: null tiles");
		return false;
	}

	if( !AIMap.IsValidTile(start) || !AIMap.IsValidTile(target)) {
		AILog.Info("PF:BuildRoad: no valid tile" );
		return false;
	}	

	do {
		retry_find = false;

		pathfinder.InitializePath([start], [target]);
		pathfinder.cost.slope = 50;
		local path = false;
		while (path == false) {
		  path = pathfinder.FindPath(100);
		  AIController.Sleep(1);
		}
//		AILog.Info("PathFinder: FindPath ready " + (path == null));

		while (path != null) {
			path_len = path_len + 1;	
			if (path.GetParent() != null) {
				local parnt = path.GetParent().GetTile();
    			if (!AIRoad.AreRoadTilesConnected(path.GetTile(), parnt) 
					&& (!AIBridge.IsBridgeTile(path.GetTile()) 
					    || AIBridge.GetOtherBridgeEnd(path.GetTile()) != parnt)) {
					local retry_build = false;
					local build_retries = 0;	 
					do {
						retry_build = false;
						if (AIMap.DistanceManhattan(path.GetTile(), parnt) == 1 ) {
//						   AILog.Info("PathFinder: tiles " + 
//								AIMap.GetTileX(path.GetTile()) + " " + AIMap.GetTileY(path.GetTile()) +
//								AIMap.GetTileX(parnt) + " " + AIMap.GetTileY(parnt));
		      			local built_road = AIRoad.BuildRoad(path.GetTile(), parnt);
							if (!built_road) {
								err = AIError.GetLastError();
								switch (err) {
									/* ignore these errors */
									case AIError.ERR_NONE: 	
									case AIError.ERR_ALREADY_BUILT: 
										/* decrement retry counter, so it does not limit the nr of retries 
											else after 35 tiles over existing road, the building stops 
										*/	 									
										if (build_retries) build_retries = build_retries - 1;
									break;
									/* can't handle this locally, return unsuccessful */
									case AIError.ERR_PRECONDITION_FAILED:
									case AIError.ERR_NEWGRF_SUPPLIED_ERROR:
									case AIError.ERR_NOT_ENOUGH_CASH:  
									case AIError.ERR_LOCAL_AUTHORITY_REFUSES: 
										AILog.Info("Build road failed(fatal)"+ AIError.GetLastErrorString()+" "+
										AIMap.GetTileX(parnt)+" " + AIMap.GetTileY(parnt)
								  		+" "+AIMap.GetTileX(path.GetTile())+" " +	AIMap.GetTileY(path.GetTile())+" " + AITile.GetSlope(path.GetTile())+" " +
					  					AITile.GetSlope(parnt));
										return false;
									break;
									case AIError.ERR_VEHICLE_IN_THE_WAY: 
										AILog.Info("Build road failed (retry)"+ AIError.GetLastErrorString()+" "+
										AIMap.GetTileX(parnt)+" " + AIMap.GetTileY(parnt)
								  		+" "+AIMap.GetTileX(path.GetTile())+" " + AIMap.GetTileY(path.GetTile())+" " + AITile.GetSlope(path.GetTile())+" " +
								  		AITile.GetSlope(parnt));	
										AIController.Sleep(1);
										retry_build = true;
									break;
									case AIError.ERR_AREA_NOT_CLEAR: 	
										AILog.Info("Build road failed (demolish + retry)"+ AIError.GetLastErrorString()+" "+
										AIMap.GetTileX(parnt)+" " + AIMap.GetTileY(parnt)
							  			+" "+AIMap.GetTileX(path.GetTile())+" " +
									      AIMap.GetTileY(path.GetTile())+" " + AITile.GetSlope(path.GetTile())+" " +
							  			AITile.GetSlope(parnt));	
										AITile.DemolishTile(path.GetTile());
										retry_build = false;
										retry_find = true;
										break;
									case AIError.ERR_OWNED_BY_ANOTHER_COMPANY :
									case AIError.ERR_FLAT_LAND_REQUIRED: 	
									case AIError.ERR_LAND_SLOPED_WRONG: 	
									case AIError.ERR_SITE_UNSUITABLE: 	
									case AIError.ERR_TOO_CLOSE_TO_EDGE: 
										AILog.Info("Build road failed (replan)"+ AIError.GetLastErrorString()+" "+
										AIMap.GetTileX(parnt)+" " + AIMap.GetTileY(parnt)
					  					+" "+AIMap.GetTileX(path.GetTile())+" " + AIMap.GetTileY(path.GetTile())+" " + AITile.GetSlope(path.GetTile())+" " +
							  			AITile.GetSlope(parnt));	
										retry_build = false;
										retry_find = true;
										break;
									case AIError.ERR_UNKNOWN:
									default:
										AILog.Info("Build road failed (replan)"+ AIError.GetLastErrorString()+" "+
										AIMap.GetTileX(parnt)+" " + AIMap.GetTileY(parnt)
						  				+" "+AIMap.GetTileX(path.GetTile())+" " +AIMap.GetTileY(path.GetTile())+" " + AITile.GetSlope(path.GetTile())+" " +
					  					AITile.GetSlope(parnt));	
										retry_find = true;
										break;
								}
							} 
							build_retries++;
						}
						else {
							AILog.Info("PathFinder: build bridge");
					      /* Build a bridge or tunnel. */
					      if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
					        /* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
				   	     if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
			      		  if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == parnt) {
	         					if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
										AILog.Info("Build tunnel failed");
	          					}
   				      	} else {
			         	   	local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), parnt) + 1);
         					 	bridge_list.Valuate(AIBridge.GetMaxSpeed);
					          	bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
				   	       	if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), parnt)) {
										AILog.Info("Build bridge failed");
	          				 	}
								}
   	     				}
						}	
					} while (retry_build && build_retries < 80 && !retry_find);
    			}
  			}
			path = path.GetParent();
		}
		plan_retries++;
	}	while (retry_find && (plan_retries < 10));

	return path_len;
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
	function BuildDepot(tile);
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
	local pf = PathFinder();
	local connected = pf.BuildRoad(busstop, town_exit0); 
	if (!connected){
		AILog.Info("CreateExitRoute failed");
	}
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
function TownManager::BuildDepot(tile)
{
	local found = false;
	local success = false;

	local adjacentTiles = Tile.GetAdjacentTiles(tile);

	for(local tile2 = adjacentTiles.Begin(); 
			adjacentTiles.HasNext() && !found; 
			tile2 = adjacentTiles.Next()) {
		if(AIRoad.IsRoadTile(tile2) ) {
			success = true;
			//local bbpf = PathFinder();
			local count = 0;
			while(!success && (count < 100)){
				local pathlen = AIRoad.BuildRoad(tile2, tile);
//				AILog.Info("Build busstop pathlen " + pathlen);
				if (pathlen == 2) {
					success = true; 
				} else {
					count = count + 1;
				}
			}
			local truck = AIRoad.ROADVEHTYPE_BUS; 
			local adjacent = AIStation.STATION_NEW;
			if (success) {
				AITile.DemolishTile(tile);
				// AITile.DemolishTile(tile2);
				AIRoad.BuildRoad(tile2, tile);
				success = AIRoad.BuildRoadDepot(tile, tile2);
			}
			found = true;
		}
	}

	if (!success) {
		AILog.Info("Build depot failed "+ AIError.GetLastErrorString());
//		AISign.BuildSign(tile,"bbs");
	}
	return tile;	
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
			success = true;
			//local bbpf = PathFinder();
			local count = 0;
			while(!success && (count < 100)){
				local pathlen = AIRoad.BuildRoad(tile2, tile);
//				AILog.Info("Build busstop pathlen " + pathlen);
				if (pathlen == 2) {
					success = true; 
				} else {
					count = count + 1;
				}
			}
			local truck = AIRoad.ROADVEHTYPE_BUS; 
			local adjacent = AIStation.STATION_NEW;
			if (success) {
				AITile.DemolishTile(tile);
				// AITile.DemolishTile(tile2);
				AIRoad.BuildRoad(tile2, tile);
				success = AIRoad.BuildRoadStation(tile, tile2, truck, adjacent);
			}
			found = true;
		}
	}

	if (!success) {
		AILog.Info("Build busstop failed "+ AIError.GetLastErrorString());
//		AISign.BuildSign(tile,"bbs");
	}
	return tile;	
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
		local pf = PathFinder();
		if (connected && newline) {
			connected = pf.BuildRoad(town_exit[0], town_exit[1]); 
			AILog.Info("CreateNewLine: connected after buildroad "+ connected);
			if (!connected) {
				AILog.Info("Connect exits failed "+ AIError.GetLastErrorString());
				if (pf.err == AIError.ERR_NOT_ENOUGH_CASH){
					try_rebuild = true;
					AILog.Info("CreateNewLine: try rebuild = true");
				}  
			}
		}

		// make sure the depot and station are connected
		if(connected) {
			connected = pf.BuildRoad(AIRoad.GetRoadStationFrontTile(stations[0][0]), AIRoad.GetRoadDepotFrontTile(depot)) ;
			// make sure the depot and town_exit are connected for a nicer route
			if(connected){
				connected = pf.BuildRoad(town_exit[0], AIRoad.GetRoadDepotFrontTile(depot)) ;
			} 
			else {
				AILog.Info("Connect busstop 0 and depot failed"+ AIError.GetLastErrorString());
			}
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
									local dpf = PathFinder();
									local success = false;
									local count = 0;
									while(!success && (count < 100)){
										local pathlen = dpf.BuildRoad(tile2, aitile);
										if (pathlen == 2) {
											success = true; 
										} else {
											count = count + 1;
										}
									}
									if (success) {
										found = AIRoad.BuildRoadDepot(aitile, tile2)
									}
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
	
}
 
 
 
function rocketAI::Start()
{
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
	local bus_model = 0;
	local build = 0;
	local depot = 0;
	local station_a = 0;
	local station_b = 0;
	
	
	/* Get a list of all towns on the map. */
	local townlist = AITownList();
	/* Sort the list by population, highest population first. */
	townlist.Valuate(AITown.GetPopulation);
	townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	/* Pick the two towns with the highest population. */
	local townid_a = townlist.Begin();
	local teller = 1;
	
	/* Lage liste over forskjellige busstyper */
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

	bus_model = engine_list.Begin();
	
	
	/* Bygger vei fra den største byen til de 5 neste byene på by-lista. */
	
	for( local k = 1; k<=5; k++ ) {
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
				}
				else {
				/* Build a bridge or tunnel. */
					if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
						/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
						if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
						if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
							if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
								/* An error occured while building a tunnel. TODO: handle it. */
							}
						} 
						else {
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
		AILog.Info(AITown.GetName(townid_a) + " is connected to " + AITown.GetName(townid_b));
		// AILog.Info(townid_a);
		// AILog.Info(AITown.GetLocation(townid_a));
		// AILog.Info(TownManager.FindLineBusStopLocation(townid_a, passenger_cargo_id, true));
		
		if (teller == 1) {
		station_a = TownManager.BuildBusStop(TownManager.FindLineBusStopLocation(townid_a, passenger_cargo_id, true));
		depot = TownManager.BuildDepot(TownManager.FindLineBusStopLocation(townid_a, passenger_cargo_id, true));
		}
		
		local station_b = TownManager.BuildBusStop(TownManager.FindLineBusStopLocation(townid_b, passenger_cargo_id, true));
		local build = AIVehicle.BuildVehicle(depot, bus_model);
		AIOrder.AppendOrder(build, depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
		AIOrder.AppendOrder(build, station_a, AIOrder.AIOF_NONE); 
		AIOrder.AppendOrder(build, station_b, AIOrder.AIOF_NONE);
		AIVehicle.StartStopVehicle(build);
		
		teller++;
	}
	/* Ferdig med å lage byer. */
	AILog.Info("Done");
}