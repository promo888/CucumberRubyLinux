function getData() {
  return {
    "gantt": {
      "type": "project",
      "controller": {
        "treeData": {
          "children": [{
            "treeDataItemData": {"id": 4, "name": "Initial Planning"},
            "children": [{
              "treeDataItemData": {
                "id": 5,
                "name": "Initial Phase #1",
                "rowHeight": 30,
                "actualStart": 1393027200000,
                "actualEnd": 1393977600000,
                "baselineStart": 1393113600000,
                "baselineEnd": 1394150400000,
                "progressValue": "40%",
                "connector": [{"connectTo": 6}]
              }
            }, {
              "treeDataItemData": {
                "id": 6,
                "name": "Initial Phase #2",
                "actualStart": 1394064000000,
                "actualEnd": 1394150400000,
                "rowHeight": 30,
                "connector": [{"connectTo": 7}]
              }
            }, {
              "treeDataItemData": {
                "id": 7,
                "name": "Initial Phase #3",
                "rowHeight": 30,
                "actualStart": 1394323200000,
                "actualEnd": 1394582400000
              }
            }]
          }, {
            "treeDataItemData": {"id": 0, "name": "Additional Planning"},
            "children": [{
              "treeDataItemData": {
                "id": 1,
                "name": "Additional Phase #1",
                "actualStart": 1391990400000,
                "actualEnd": 1392422400000,
                "progressValue": "30%",
                "rowHeight": 30,
                "connector": [{"connectTo": 2}]
              }
            }, {
              "treeDataItemData": {
                "id": 2,
                "name": "Additional Phase #2",
                "actualStart": 1392249600000,
                "actualEnd": 1392595200000,
                "baselineStart": 1392163200000,
                "baselineEnd": 1392681600000,
                "rowHeight": 30,
                "connector": [{"connectTo": 3}]
              }
            }, {
              "treeDataItemData": {
                "id": 3,
                "name": "Additional Phase #3",
                "actualStart": 1392681600000,
                "actualEnd": 1392940800000,
                "rowHeight": 30,
                "connector": [{"connectTo": "milestone"}]
              }
            }, {
              "treeDataItemData": {
                "id": "milestone",
                "name": "Additional Summary Meeting",
                "actualStart": 1393002000000,
                "rowHeight": 30
              }
            }]
          }, {
            "treeDataItemData": {"id": 8, "name": "Quality Assurance"},
            "children": [{
              "treeDataItemData": {
                "id": 9,
                "name": "QA Phase #1",
                "rowHeight": 30,
                "actualStart": 1394236800000,
                "actualEnd": 1394668800000,
                "baselineStart": 1394409600000,
                "baselineEnd": 1394668800000,
                "connector": [{"connectTo": 10}]
              }
            }, {
              "treeDataItemData": {
                "id": 10,
                "name": "QA Phase #2",
                "actualStart": 1394841600000,
                "actualEnd": 1395014400000,
                "rowHeight": 30,
                "progressValue": "10%",
                "connector": [{"connectTo": 11}]
              }
            }, {
              "treeDataItemData": {
                "id": 11,
                "name": "QA Phase #3",
                "rowHeight": 30,
                "actualStart": 1395187200000,
                "actualEnd": 1395705600000,
                "connector": [{"connectTo": 8, "connectorType": "finishstart"}]
              }
            }]
          }]
        }
      }
    }
  };
}
