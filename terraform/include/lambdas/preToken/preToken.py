def lambda_handler(event, context):
    """
    This function handles adding a custom claim to the cognito ID token.
    """
    
    # grab requestor's email address
    custom_groups = event['request']['userAttributes']['custom:groups']
    
    #Groups come in this strange format from AzureAD so we need to make them a list
    #Example: 
    groups = custom_groups.lstrip('[').rstrip(']').split(', ')
    # this allows us to override claims in the id token
    # "claimsToAddOrOverride" is the important part 
    event["response"]["claimsOverrideDetails"] = { 
        "claimsToAddOrOverride": {
            #Cognito does not accept lists as an standard attribute
            "groups": ",".join(groups)
         
        },
        "groupOverrideDetails": {
                #This will update the cognito:groups attribute
                "groupsToOverride": groups
        }
    }
         
    # return modified ID token to Amazon Cognito 
    return event 
