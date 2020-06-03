pipeline {
  agent any         
	parameters {
		string(name:'serverlist', description: 'Enter Comma Seperated List Of Servers [ Eg:- server1,server2,server3 ]:')
	}	
    stages {
        stage('Preparing Inventory') { 
          steps {
						sh '''
            #!/bin/bash
            rm -rf scripts
            git clone https://github.com/kiranthaikkandy/scripts.git
            cp -pr scripts/serverlisttemplate.txt servers
            cp -pr scripts/inventorytmp.txt inventory
            echo $serverlist|tr ',' '\n' >> inventory
            echo $serverlist|tr ',' '\n' >> servers
            cat servers
            rm -rf servers
			      '''
          }
        }
        stage('Confirm Patching Inventory') { 
          steps {
            sh '''
            #!/bin/bash
            echo "Confirm To Continue With Patching"
            '''
          }  
          input {
            message "Should We Continue with Patching?"
            ok "Yes, we should."
          }     
        }
        stage('Pre-Check') { 
          steps {
            sh '''
            #!/bin/bash
            ansible-playbook  scripts/precheck.yaml -i inventory  
            rm -rf inventory
            '''
          }
        }  
    }
}