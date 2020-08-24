module.exports = {
  someSidebar: [
    'getting_started',
    {
       type: "category",
       label: "Concepts",
       items: [
         "concepts/value_notifier",
         
       ]
    },
    {
      type: "category",
      label: "Command",
      items: [
        "command_details/command_encounter",
        "command_details/command_full_power",        
      ]

    },{
      type: "category",
      label: "Command in Detail ",
      items: [        
        "command_details/command",
        "command_details/command_types",        
        "command_details/command_interaction",
        "command_details/error_handling",
        "command_details/command_attributes",
        
      ]

    },
    'command_builder'   
  ]
};
