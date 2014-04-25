Accounts.config
  forbidClientAccountCreation: true
if !ServiceConfiguration.configurations.findOne({service: "steam"})?
  ServiceConfiguration.configurations.insert
    service: "steam"
    apiKey: "24C83FB2B2BCD5C318C86C568DB2A79C"
