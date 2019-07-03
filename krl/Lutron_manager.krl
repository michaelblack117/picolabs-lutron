ruleset Lutron_manager {
  meta {
    use module io.picolabs.wrangler alias wrangler

    shares __testing, data, extractData, fetchXML, fetchLightIDs, fetchShadeIDs,
            fetchAreas, isConnected, lightIDs, shadeIDs, areas, getDeviceByName, devicesAndDetails, removeDevice
    provides data, isConnected, lightIDs, shadeIDs, areas, integrationIDs, devicesAndDetails
  }
  global {
    __testing = { "queries":
      [ { "name": "data" },
        // { "name": "extractData" },
        { "name": "isConnected" },
        // { "name": "fetchXML" },
        // { "name": "fetchLightIDs" },
        // { "name": "fetchShadeIDs" },
        // { "name": "fetchAreas" },
        { "name": "lightIDs" },
        { "name": "shadeIDs" },
        { "name": "areas" },
        { "name": "getDeviceByName", "args": [ "name" ] },
        { "name": "devicesAndDetails" },
        { "name": "removeDevice", "args": [ "id" ] }
      ],  "events": [ { "domain": "lutron", "type": "login",
                    "attrs": [ "host", "username", "password" ] },
        { "domain": "lutron", "type": "logout" },
        { "domain": "lutron", "type": "sync_data"},
        { "domain": "lutron", "type": "sendCMD", "attrs": [ "cmd" ] },
        { "domain": "lutron", "type": "create_lights" },
        { "domain": "lutron", "type": "create_shades" },
        { "domain": "lutron", "type": "create_default_areas" },
        { "domain": "lutron", "type": "create_group", "attrs": [ "name" ] },
        { "domain": "lutron", "type": "add_device_to_group",
                    "attrs": [ "device_name", "device_type", "group_name" ] },
        { "domain": "lutron", "type": "add_group_to_group",
                    "attrs": [ "child_group_name", "parent_group_name" ] }
      ]
    }
    data = function() {
      ent:data
    }
    extractData = function() {
      xml = fetchXML();
      // grabs area names, and light and shade integration ids from an xml file
      telnet:extractDataFromXML(xml)
    }
    isConnected = function() {
      ent:isConnected.defaultsTo(false)
    }
    fetchXML = function() {
      // lutron provided host for xml data
      url = "http://" + telnet:host().klog("host") + "/DbXmlInfo.xml";
      http:get(url){"content"}
    }
    fetchAreas = function() {
      ent:data.filter(function(v,k) {
        v{"lights"}.length() > 0
      }).keys()
    }
    fetchLightIDs = function() {
      ent:data.map(function(v,k) {
        v{"lights"}
      }).filter(function(v,k) {
        v != []
      }).values().reduce(function(a,b) {
        a.append(b)
      })
    }
    fetchShadeIDs = function() {
      ent:data.map(function(v,k) {
        v{"shades"}
      }).filter(function(v,k) {
        v != []
      }).values().reduce(function(a,b) {
        a.append(b)
      })
    }
    areas = function() {
      ent:areas.defaultsTo([])
    }
    lightIDs = function() {
      ent:lightIDs.defaultsTo([])
    }
    shadeIDs = function() {
      ent:shadeIDs.defaultsTo([])
    }
    getDeviceByName = function(name) {
      ent:devices.map(function(v,k) {
        v.filter(function(v,k) {
          v{"name"} == name
        })
      }).values().reduce(function(a,b) {
        a.put(b)
      }).values()[0]
    }
    arraysAreEqual = function(a,b) {
      a.length() != b.length() => false |
      [a, b].pairwise(function(x, y) {x == y}).all(function(x) {x == true})
    }
    devicesAndDetails = function() {
      ent:devices
    }
    removeDevice = function(id) {
      ent:devices.map(function(v,k) {
        v.filter(function(v,k) {
          k != id
        })
      })
    }
    app = {"name":"Lutron Manager","version":"0.0"/* img: , pre: , ..*/};
    // image url: https://serenaprouat.lutron.com/media/wysiwyg/img_logo_lutron.gif

    bindings = function() {
      {
        // "lights": lightIDs(),
        // "shades": shadeIDs(),
        // "isConnected": isConnected()
      }
    }
  }

  rule discovery {
    select when manifold apps
    send_directive("lutron app discovered...",
      { "app": app,
        "iconURL": "https://lh3.ggpht.com/CIySCkIa6cshHVwZzEkpEyBtIfWWLLJ_w8GBKuUQRk8iXkB6sg9FbE5ZTNuuMJKRrw=s360-rw",
        "rid": meta:rid,
        "bindings": bindings()
      });
  }

  rule initialized {
    select when wrangler ruleset_installed
    fired {

    }
  }

  rule lutron_online {
    select when system online
    fired {
      ent:isConnected := false;
      ent:devices{"areas"} := ent:devices{"areas"}.defaultsTo({}); // move these to ruleset_installed when in production
      ent:devices{"groups"} := ent:devices{"groups"}.defaultsTo({});
      ent:devices{"lights"} := ent:devices{"lights"}.defaultsTo({});
      ent:devices{"shades"} := ent:devices{"shades"}.defaultsTo({});
      ent:lightIDs := ent:lightIDs.defaultsTo([]);
      ent:shadeIDs := ent:shadeIDs.defaultsTo([]);
      ent:areas := ent:areas.defaultsTo([]);
    }
  }

  rule login {
    select when lutron login
    pre {
      shellPrompt = "QNET>"
      params = {"host": event:attr("host"),
                "port": 23,
                "shellPrompt": shellPrompt,
                "loginPrompt": "login:",
                "passwordPrompt": "password:",
                "username": event:attr("username"),
                "password": event:attr("password"),
                "failedLoginMatch": "bad login",
                "initialLFCR": true,
                "timeout": 1800000 } // 30 minutes
    }
    every {
      telnet:connect(params) setting(response)
      send_directive("login_attempt",
        {"isConnected": response.match(shellPrompt), "result": response})
    }

    fired {
      raise lutron event "evaluate_login_response"
        attributes {"isConnected": response.match(shellPrompt), "response": response }
    }
  }

  rule evaluate_login_response {
    select when lutron evaluate_login_response
    pre {
      resp = event:attr("response")
      isConnected = event:attr("isConnected");
    }
    if isConnected then noop()
    fired {
      ent:isConnected := true;
      raise lutron event "sync_data" if (lightIDs().length() == 0)
    }
  }

  rule logout {
    select when lutron logout
    telnet:disconnect()
    fired {
      ent:isConnected := false
    }
  }

  rule sync_data {
    select when lutron sync_data
    pre {
      data = extractData()
      update_lights = (not arraysAreEqual(ent:lightIDs, fetchLightIDs())).klog("update_lights:")
      update_shades = (not arraysAreEqual(ent:shadeIDs, fetchShadeIDs())).klog("update_shades:")
      update_areas =  (not arraysAreEqual(ent:areas, fetchAreas())).klog("update_areas")
    }
    always {
      ent:data := data;
      raise lutron event "create_lights" if update_lights;
      raise lutron event "create_shades" if update_shades;
      raise lutron event "create_default_areas" if update_areas;
    }
  }

  rule send_command {
    select when lutron sendCMD
    if isConnected() then every {
      telnet:sendCMD(event:attr("cmd")) setting(result)
      send_directive(result)
    }
    notfired {
      raise lutron event "error" attributes { "message": "you are not logged in" }
    }
  }

  rule create_light_picos {
    select when lutron create_lights
    foreach fetchLightIDs() setting(light)
    pre {
      name = "Light " + light
      exists = ent:lightIDs >< light
    }
    if not exists then noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "type": "light",
          "color": "#eeee00",
          "IntegrationID": light,
          "rids": [
            "Lutron_light"
            ]
        };
      ent:lightIDs := ent:lightIDs.append(light)
    }
  }

  rule create_shade_picos {
    select when lutron create_shades
    foreach fetchShadeIDs() setting(shade)
    pre {
      name = "Shade " + shade
      exists = ent:shadeIDs >< shade
    }
    if not exists then noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "type": "shade",
          "color": "#8e8e8e",
          "IntegrationID": shade,
          "rids": [
            "Lutron_shade"
            ]
        };
      ent:shadeIDs := ent:shadeIDs.append(shade)
    }
  }

  rule create_area_picos {
    select when lutron create_default_areas
    foreach ent:data setting(area)
    pre {
      name = area{"name"}
      id = area{"id"}
      lights = area{"lights"}
      exists = ent:areas >< name
    }
    if (lights != []) && (not exists) then noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "type": "area",
          "IntegrationID": id,
          "light_ids": lights,
          "color": "#EB4839",
          "rids": [
            "Lutron_area"
            ]
        };
      ent:areas := ent:areas.append(name)
    }
  }

  rule create_lutron_group {
    select when lutron create_group
    pre {
      name = event:attr("name") || false
    }
    if name then noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "type": "group",
          "color": "#3CAD5E",
          "rids": [
            "Lutron_group"
            ]
        };
    }
    else {
      raise lutron event "error"
        attributes {"message": "Must provide a name for the new lutron group"}
    }
  }

  rule on_child_initialized {
    select when wrangler child_initialized
    pre {
      attrs = event:attrs.klog("attrs")
      picoID = event:attr("id")
      name = event:attr("name")
      type = event:attr("rs_attrs"){"type"}
      eci = event:attr("eci")
      grouping = type + "s"
    }
    fired {
      ent:devices{[grouping, picoID]} := {"id": picoID, "name": name, "type": type, "eci": eci}
    }
  }

  rule on_child_name_changed {
    select when lutron child_name_changed
    pre {
      id = event:attr("child_id")
      category = event:attr("child_type") + "s"
      name = event:attr("new_name")
      updated_devices = ent:devices.put([category, id, "name"], name)
    }
    fired {
      ent:devices := updated_devices
    }
  }

  rule on_child_deletion {
    select when wrangler delete_child
    pre {
      picoID = event:attr("id")
      updated_devices = removeDevice(picoID)
    }
    fired {
      ent:devices := updated_devices
    }
  }

  rule delete_lutron_group {
    select when lutron delete_group
    pre {
      name = event:attr("name")
      id = getDeviceByName(name){"id"}
    }
    if id then noop()
    fired {
      raise wrangler event "child_deletion"
        attributes {"name": name, "id": id}
    }
  }

  rule add_device_to_group {
    select when lutron add_device_to_group
    pre {
      device = getDeviceByName(event:attr("device_name"))
      device_eci = device{"eci"}
      device_type = device{"type"}
      group_eci = getDeviceByName(event:attr("group_name")){"eci"}
    }
    if (device_eci && group_eci) then
    event:send(
      {
        "eci": group_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": {
          "name": event:attr("device_name"),
          "Rx_role": "controller",
          "Tx_role": device_type,
          "channel_type": "subscription",
          "wellKnown_Tx": device_eci
        }
      })

    notfired {
      raise lutron event "error"
        attributes {"message": "Invalid device_name or group_name"}
    }
  }

  rule add_group_to_group {
    select when lutron add_group_to_group
    pre {
      child_group_eci = getDeviceByName(event:attr("child_group_name")){"eci"}.klog("child_eci")
      parent_group_eci = getDeviceByName(event:attr("parent_group_name")){"eci"}.klog("parent_eci")
    }
    if (child_group_eci && parent_group_eci) then
    event:send(
      {
        "eci": parent_group_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": {
          "name": event:attr("child_group_name"),
          "Rx_role": "controller",
          "Tx_role": "group",
          "channel_type": "subscription",
          "wellKnown_Tx": child_group_eci
        }
      })

    notfired {
      raise lutron event "error"
        attributes {"message": "Invalid child_group_name or parent_group_name"}
    }
  }

  rule handle_error {
    select when lutron error
    send_directive("lutron_error", {"message": event:attr("message")})
  }
}
