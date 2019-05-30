ruleset Lutron_area {
  meta {
    shares __testing, status
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "status" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "lutron", "type": "area_level", "attrs": [ "level/position" ] },
        { "domain": "lutron", "type": "area_raise" },
        { "domain": "lutron", "type": "area_lower" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }

    status = function() {
      command = "?AREA," + ent:IntegrationID + ",1";
      response = telnet:query(command);
      percentage = response.extract(re#(\d+)[.]#)[0];
      "Area " + ent:IntegrationID + " level/position: " + percentage
    }
  }

  rule initialize {
    select when wrangler ruleset_added where event:attr("rids") >< meta:rid
    pre {
      attrs = event:attr("rs_attrs")
      IntegrationID = attrs{"IntegrationID"}
      lightIDs = attrs{"light_ids"}
    }
    always {
      ent:IntegrationID := IntegrationID;
      ent:lights := lightIDs;
    }
  }

  rule level_position {
    select when lutron area_level or lutron area_position
    pre {
      command = "#AREA," + ent:IntegrationID + ",1," + event:attr("level/position")
      result = telnet:sendCMD(command)
    }
    send_directive("lutron_area", {"result": result})
  }

  rule raise {
    select when lutron area_raise
    pre {
      command = "#AREA," + ent:IntegrationID + ",2"
      result = telnet:sendCMD(command)
    }
    send_directive("lutron_area", {"result": result})
  }

  rule lower {
    select when lutron area_lower
    pre {
      command = "#AREA," + ent:IntegrationID + ",3"
      result = telnet:sendCMD(command)
    }
    send_directive("lutron_area", {"result": result})
  }
}