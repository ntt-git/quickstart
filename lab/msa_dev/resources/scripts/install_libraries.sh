#!/bin/bash
#set -x

PROG=$(basename $0)

DEV_BRANCH=default_dev_branch
GITHUB_DEFAULT_BRANCH=master
QUICKSTART_DEFAULT_BRANCH=master
INSTALL_LICENSE=false
ASSUME_YES=false

#
# versioning of the libraries that are installed by the script
#
TAG_WF_KIBANA_DASHBOARD=v2.8.4      # https://github.com/openmsa/workflow_kibana
TAG_WF_TOPOLOGY=v2.8.6              # https://github.com/openmsa/workflow_topology
TAG_PHP_SDK=v2.6.0                  # https://github.com/openmsa/php-sdk
TAG_WF_MINILAB=v2.6.0               # https://github.com/ubiqube/workflow_quickstart_minilab
TAG_PYTHON_SDK=v2.8.5               # https://github.com/openmsa/python-sdk
TAG_WF_ETSI_MANO=v3.0.0             # https://github.com/openmsa/etsi-mano-workflows
TAG_ADAPTER=v2.8.6                  # https://github.com/openmsa/Adapters
TAG_WORKFLOWS=v2.8.5                # https://github.com/openmsa/Workflows
TAG_MICROSERVICES=v2.8.6            # https://github.com/openmsa/Microservices
TAG_BLUEPRINTS=CCLA-2.0.0           # https://github.com/openmsa/Blueprints


install_license() {

    if [ $INSTALL_LICENSE == true  ];
    then
        echo "-------------------------------------------------------"
        echo "INSTALL EVAL LICENSE"
        echo "-------------------------------------------------------"
        /usr/bin/install_license.sh
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
}

init_intall() {

    git config --global alias.lg "log --graph --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%C(reset) %s %C(bold blue)<%an>%C(reset) %C(green)(%ar)%C(reset)' --abbrev-commit --date=relative";
    git config --global push.default simple;
    git config --global pull.rebase false;
    mkdir -p /opt/fmc_entities;
    mkdir -p /opt/fmc_repository/CommandDefinition;
    mkdir -p /opt/fmc_repository/CommandDefinition/microservices;
    mkdir -p /opt/fmc_repository/Configuration;
    mkdir -p /opt/fmc_repository/Datafiles;
    mkdir -p /opt/fmc_repository/Datafiles/Environments;
    mkdir -p /opt/fmc_repository/Documentation;
    mkdir -p /opt/fmc_repository/Firmware;
    mkdir -p /opt/fmc_repository/License;
    mkdir -p /opt/fmc_repository/Process;
    mkdir -p /opt/fmc_repository/Blueprints;
    mkdir -p /opt/fmc_repository/Blueprints/local;

    chown -R ncuser.ncuser /opt/fmc_repository /opt/fmc_entities
}

update_git_repo () {
    REPO_URL=$1
    REPO_BASE_DIR=$2
    REPO_DIR=$3
    DEFAULT_BRANCH=$4
    DEFAULT_DEV_BRANCH=$5
    TAG=$6
    RESET_REPO=$7

    cd $REPO_BASE_DIR
    echo ">> "
    echo ">> $REPO_URL"
    if [ "$RESET_REPO" == true ];
    then
        echo "> deleting repository"
        rm -rf $REPO_DIR
    fi

    if [ -d $REPO_DIR ];
    then
        cd $REPO_DIR
        ## get current branch and store in variable CURRENT_BR
        CURRENT_BR=`git rev-parse --abbrev-ref HEAD`
        echo "> Current working branch: $CURRENT_BR"
        if [[ $ASSUME_YES == false && "$CURRENT_BR" == "master" ]];
        then
            echo "> WARNING: your current branch is $CURRENT_BR, to be safe, you may want to switch to a working branch (default_dev_branch is the factory default for development) > switch ? [y]/[N]"
            read  yn
            case $yn in
                [Yy]* )
                    echo "> Enter the name of the working branch (enter $CURRENT_BR to stay on your current branch):"
                    read  br
                    if [ -z "$br" ];
                    then
                        echo "> ERROR: invalid branch name, exiting..."
                        exit 0
                    else
                        # checkout or create and checkout the branch
                        echo "> Switching to $br (the branch will be created if it doesn't exist yet)"
                        git checkout $br 2>/dev/null || git checkout -b $br
                        CURRENT_BR=$br
                    fi
                    ;;
                [Nn]* )
                    echo "> stay on master ? [y]/[N]"
                    read  resp
                    if [[ ! -z "$resp" && "$resp" == "y" ]];
                    then
                        echo "> running installation/update on master branch on local repository"
                    else
                        echo "> cancelling installation, exiting... "
                        exit 0
                    fi
                    ;;
                * )
                    echo "> exiting... "
                    exit 0
                   ;;
            esac
        fi

        if [[ $ASSUME_YES == false && ! -z "$TAG" ]];
        then
            echo "> installing version $TAG for $REPO_DIR"
            echo "> available release branches"
            git branch --list v*
            git fetch --tags
            echo "> available release tags:"
            git tag -l v*
            if [ ! `git tag --list $TAG` ]
            then
                echo "> WARNING: tag $TAG not found, current branch is $CURRENT_BR"
                echo  "> (c) Cancel installation"
                echo  "> (I) Ignore and keep existing version - default"
                read -p  "[I]/[c]" resp
                if [[ $resp != "" && $resp == "c" ]];
                then
                    echo "> cancelling installation, exiting... "
                    exit 0
                fi
            fi
            git stash
            git checkout master
            git pull
            if [ `git branch --list $TAG` ]
            then
                echo "> local branch $branch_name already exists."
                echo "> delete the local branch created for the tag $TAG"
                git branch -D $TAG
            fi
            echo "> Create a new branch: $TAG based on the tag $TAG"
            git checkout tags/$TAG -b $TAG
        elif [[ $ASSUME_YES == false && ! -z "$DEFAULT_BRANCH" ]];
        then
            git stash
            echo "> Checking merge $DEFAULT_BRANCH to $CURRENT_BR"
            git merge --no-commit --no-ff $DEFAULT_BRANCH
            CAN_MERGE=$?
            if [ $CAN_MERGE == 0 ];
            then
                echo "> Auto-merge $DEFAULT_BRANCH to $CURRENT_BR is possible"
                if [ $ASSUME_YES == false ];
                then
                    while true; do

                    echo "> merge $DEFAULT_BRANCH to current working branch $CURRENT_BR ? [y]/[N]"
                    read yn

                    case $yn in
                        [Yy]* )
                            git pull origin $DEFAULT_BRANCH --prune; break
                        ;;
                        [Nn]* )
                            echo "> skip merge "
                            break
                        ;;
                        * )
                            echo "Please answer yes or no."
                        ;;
                    esac
                    done
                else
                    git pull origin $DEFAULT_BRANCH --prune
                fi
            else
                echo "> ERROR: conflict found when merging $DEFAULT_BRANCH to $CURRENT_BR."
                echo ">       auto-merge not possible"
                echo ">       login to the container msa_dev and merge manually if merge is needed"
                echo ">       relaunch install_libraries after merge is done"
                echo ">       git repository at $REPO_BASE_DIR/$REPO_DIR"
                git merge --abort
                exit 1
            fi;
            echo "> Check out $DEFAULT_BRANCH and get the latest code"
            git checkout $DEFAULT_BRANCH;
            git pull;
            echo "> Back to working branch"
            git checkout $CURRENT_BR
            git stash pop
        fi;
    else
        git clone $REPO_URL $REPO_DIR
        cd $REPO_DIR
        git checkout $DEFAULT_BRANCH;
        if [ ! -z "$TAG" ];
        then
            echo "> Create a new branch: $TAG based on the tag $TAG"
            git checkout tags/$TAG -b $TAG
        fi

        if [ ! -z "$DEFAULT_DEV_BRANCH" ];
        then
            echo "> Create a new developement branch: $DEFAULT_DEV_BRANCH based on $DEFAULT_BRANCH"
            git checkout -b $DEFAULT_DEV_BRANCH
        fi
    fi;
    echo ">>"
    echo ">> DONE"
}

update_all_github_repo() {
    echo "-------------------------------------------------------------------------------"
    echo " Update the github repositories "
    echo "-------------------------------------------------------------------------------"
    install_type=$1
    git config --global user.email devops@openmsa.co

    if [[ $install_type = "all" || $install_type = "da" ]];
    then
        update_git_repo "https://github.com/openmsa/Adapters.git" "/opt/devops" "OpenMSA_Adapters" $GITHUB_DEFAULT_BRANCH "" $TAG_ADAPTER false
    fi

    if [[ $install_type = "all" || $install_type = "ms" ]];
    then
        update_git_repo "https://github.com/openmsa/Microservices.git" "/opt/fmc_repository" "OpenMSA_MS" $GITHUB_DEFAULT_BRANCH "" $TAG_MICROSERVICES false
    fi

    if [[ $install_type = "all" || $install_type = "wf" ]];
    then
        update_git_repo "https://github.com/openmsa/workflow_kibana.git" "/opt/fmc_repository" "OpenMSA_Workflow_Kibana" $GITHUB_DEFAULT_BRANCH "" $TAG_WF_KIBANA_DASHBOARD false
        update_git_repo "https://github.com/openmsa/workflow_topology.git" "/opt/fmc_repository" "OpenMSA_Workflow_Topology" $GITHUB_DEFAULT_BRANCH "" $TAG_WF_TOPOLOGY false
        update_git_repo "https://github.com/openmsa/Workflows.git" "/opt/fmc_repository" "OpenMSA_WF" $GITHUB_DEFAULT_BRANCH "" $TAG_WORKFLOWS false
        update_git_repo "https://github.com/openmsa/php-sdk.git" "/opt/fmc_repository" "php_sdk" $GITHUB_DEFAULT_BRANCH "" $TAG_PHP_SDK false
        update_git_repo "https://github.com/ubiqube/workflow_quickstart_minilab.git" "/opt/fmc_repository" "workflow_quickstart_minilab" $GITHUB_DEFAULT_BRANCH "" $TAG_WF_MINILAB true
    fi

    if [[ $install_type = "all" || $install_type = "mano" ]];
    then
       update_git_repo "https://github.com/openmsa/etsi-mano-workflows.git" "/opt/fmc_repository" "etsi-mano-workflows" $GITHUB_DEFAULT_BRANCH "" $TAG_WF_ETSI_MANO false
    fi
    
    if [[ $install_type = "ccla" ]];
    then
       update_git_repo "https://github.com/openmsa/Blueprints" "/opt/fmc_repository" "OpenMSA_Blueprints" $GITHUB_DEFAULT_BRANCH "" $TAG_BLUEPRINTS false
    fi

    if [[ $install_type = "all" || $install_type = "py" ]];
    then
        update_git_repo "https://github.com/openmsa/python-sdk.git" "/tmp/" "python_sdk" "develop" "" $TAG_PYTHON_SDK false
    fi

#    if [[ $install_type = "all" || $install_type = "quickstart" ]];
#    then
#        update_git_repo "https://github.com/ubiqube/quickstart.git" "/opt/fmc_repository" "quickstart" $QUICKSTART_DEFAULT_BRANCH "" "" true
#    fi
}

install_python_sdk() {
    echo "-------------------------------------------------------------------------------"
    echo " Install python SDK"
    echo "-------------------------------------------------------------------------------"
    mkdir -p /opt/fmc_repository/Process/PythonReference/custom
    touch /opt/fmc_repository/Process/PythonReference/custom/__init__.py
    pushd /tmp/python_sdk
    python3 setup.py -q install  --install-lib='/opt/fmc_repository/Process/PythonReference'
    popd
    rm -rf /tmp/python_sdk
}

install_microservices () {

    echo "-------------------------------------------------------------------------------"
    echo " Install some MS from OpenMSA github repo"
    echo "-------------------------------------------------------------------------------"
    cd /opt/fmc_repository/CommandDefinition/;
    echo "  >> ADVA"
    ln -fsn ../OpenMSA_MS/ADVA ADVA; ln -fsn ../OpenMSA_MS/.meta_ADVA .meta_ADVA;
    echo "  >> ANSIBLE"
    ln -fsn ../OpenMSA_MS/ANSIBLE ANSIBLE; ln -fsn ../OpenMSA_MS/.meta_ANSIBLE .meta_ANSIBLE;
    echo "  >> AWS"
    ln -fsn ../OpenMSA_MS/AWS AWS; ln -fsn ../OpenMSA_MS/.meta_AWS .meta_AWS;
    echo "  >> CHECKPOINT"
    ln -fsn ../OpenMSA_MS/CHECKPOINT CHECKPOINT; ln -fsn ../OpenMSA_MS/.meta_CHECKPOINT .meta_CHECKPOINT;
    echo "  >> CISCO"
    ln -fsn ../OpenMSA_MS/CISCO CISCO; ln -fsn ../OpenMSA_MS/.meta_CISCO .meta_CISCO;
    echo "  >> CITRIX"
    ln -fsn ../OpenMSA_MS/CITRIX CITRIX; ln -fsn ../OpenMSA_MS/.meta_CITRIX .meta_CITRIX;
    echo "  >> FLEXIWAN"
    ln -fsn ../OpenMSA_MS/FLEXIWAN FLEXIWAN; ln -fsn ../OpenMSA_MS/.meta_FLEXIWAN .meta_FLEXIWAN;
    echo "  >> FORTINET"
    ln -fsn ../OpenMSA_MS/FORTINET FORTINET; ln -fsn ../OpenMSA_MS/.meta_FORTINET .meta_FORTINET;
    echo "  >> JUNIPER"
    ln -fsn ../OpenMSA_MS/JUNIPER JUNIPER; ln -fsn ../OpenMSA_MS/.meta_JUNIPER .meta_JUNIPER;
    rm -rf  JUNIPER/SSG
    echo "  >> LINUX"
    ln -fsn ../OpenMSA_MS/LINUX LINUX; ln -fsn ../OpenMSA_MS/.meta_LINUX .meta_LINUX;
    echo "  >> MIKROTIK"
    ln -fsn ../OpenMSA_MS/MIKROTIK MIKROTIK; ln -fsn ../OpenMSA_MS/.meta_MIKROTIK .meta_MIKROTIK;
    echo "  >> OPENSTACK"
    ln -fsn ../OpenMSA_MS/OPENSTACK OPENSTACK; ln -fsn ../OpenMSA_MS/.meta_OPENSTACK .meta_OPENSTACK;
    echo "  >> ONEACCESS"
    ln -fsn ../OpenMSA_MS/ONEACCESS ONEACCESS; ln -fsn ../OpenMSA_MS/.meta_ONEACCESS .meta_ONEACCESS;
    echo "  >> PALOALTO"
    ln -fsn ../OpenMSA_MS/PALOALTO PALOALTO; ln -fsn ../OpenMSA_MS/.meta_PALOALTO .meta_PALOALTO;
    echo "  >> PFSENSE"
    ln -fsn ../OpenMSA_MS/PFSENSE PFSENSE; ln -fsn ../OpenMSA_MS/.meta_PFSENSE .meta_PFSENSE;
    echo "  >> REDFISHAPI"
    ln -fsn ../OpenMSA_MS/REDFISHAPI REDFISHAPI; ln -fsn ../OpenMSA_MS/.meta_REDFISHAPI .meta_REDFISHAPI;
    echo "  >> REST"
    ln -fsn ../OpenMSA_MS/REST REST; ln -fsn ../OpenMSA_MS/.meta_REST .meta_REST;
    echo "  >> ETSI-MANO"
    ln -fsn ../OpenMSA_MS/NFVO NFVO;  ln -fsn ../OpenMSA_MS/.meta_NFVO .meta_NFVO
    ln -fsn ../OpenMSA_MS/VNFM VNFM; ln -fsn ../OpenMSA_MS/.meta_VNFM .meta_VNFM
    ln -fsn ../OpenMSA_MS/KUBERNETES KUBERNETES; ln -fsn ../OpenMSA_MS/.meta_KUBERNETES .meta_KUBERNETES
    echo "  >> NETBOX"
    ln -fsn ../OpenMSA_MS/NETBOX NETBOX; ln -fsn ../OpenMSA_MS/.meta_NETBOX .meta_NETBOX;
    echo "  >> DELL/REDFISH"
    ln -fsn ../OpenMSA_MS/DELL DELL; ln -fsn ../OpenMSA_MS/.meta_DELL .meta_DELL;
    echo "  >> INTEL/REDFISH"
    ln -fsn ../OpenMSA_MS/INTEL INTEL; ln -fsn ../OpenMSA_MS/.meta_INTEL .meta_INTEL;
    echo "  >> HP/REDFISH"
    ln -fsn ../OpenMSA_MS/HP HP; ln -fsn ../OpenMSA_MS/.meta_HP .meta_HP;
    echo "  >> LANNER/IPMI"
    ln -fsn ../OpenMSA_MS/LANNER LANNER; ln -fsn ../OpenMSA_MS/.meta_LANNER .meta_LANNER;
    echo "  >> MONITORING/GENERIC"
    ln -fsn ../OpenMSA_MS/ASSURANCE ASSURANCE;

    echo "DONE"

}

install_workflows() {

    echo "-------------------------------------------------------------------------------"
    echo " Install Workflows from OpenMSA github github repository"
    echo "-------------------------------------------------------------------------------"
    cd /opt/fmc_repository/Process;
    echo "  >> WF references and libs"
    ln -fsn ../php_sdk/Reference Reference;
    ln -fsn ../php_sdk/.meta_Reference .meta_Reference;
    echo "  >> WF tutorials"
    ln -fsn ../OpenMSA_WF/Tutorials Tutorials;
    ln -fsn ../OpenMSA_WF/.meta_Tutorials .meta_Tutorials;
#    echo "  >> BIOS_Automation"
#    ln -fsn ../OpenMSA_WF/BIOS_Automation BIOS_Automation
#    ln -fsn ../OpenMSA_WF/.meta_BIOS_Automation .meta_BIOS_Automation
    echo "  >> ETSI-MANO $TAG_WF_ETSI_MANO"
    ln -fsn ../etsi-mano-workflows etsi-mano-workflows
    echo "  >> Private Cloud - Openstack"
    ln -fsn ../OpenMSA_WF/Private_Cloud Private_Cloud
    ln -fsn ../OpenMSA_WF/.meta_Private_Cloud .meta_Private_Cloud
    echo "  >> Ansible"
    ln -fsn ../OpenMSA_WF/Ansible_integration Ansible_integration
    #ln -fsn ../OpenMSA_WF/.meta_Ansible_integration .meta_Ansible_integration
    echo "  >> Public Cloud - AWS"
    ln -fsn ../OpenMSA_WF/Public_Cloud Public_Cloud
    ln -fsn ../OpenMSA_WF/.meta_Public_Cloud .meta_Public_Cloud
    echo "  >> Topology $TAG_WF_TOPOLOGY"
    ln -fsn ../OpenMSA_Workflow_Topology/Topology Topology
    ln -fsn ../OpenMSA_Workflow_Topology/.meta_Topology .meta_Topology
    echo "  >> Analytics $TAG_WF_KIBANA_DASHBOARD"
    ln -fsn ../OpenMSA_Workflow_Kibana/Analytics Analytics
    ln -fsn ../OpenMSA_Workflow_Kibana/.meta_Analytics .meta_Analytics
    echo "  >> MSA / Utils"
    ln -fsn ../OpenMSA_WF/Utils/Manage_Device_Conf_Variables Manage_Device_Conf_Variables
    ln -fsn ../OpenMSA_WF/Utils/.meta_Manage_Device_Conf_Variables .meta_Manage_Device_Conf_Variables
#    echo "  >> MSA / Utils"
#    ln -fsn ../OpenMSA_WF/BIOS_Automation BIOS_Automation
#    ln -fsn ../OpenMSA_WF/.meta_BIOS_Automation .meta_BIOS_Automation
#    echo "  >> AI ML Upgrade MSA"
#    ln -fsn ../OpenMSA_WF/Upgrade_MSActivator Upgrade_MSActivator
#    ln -fsn ../OpenMSA_WF/.meta_Upgrade_MSActivator .meta_Upgrade_MSActivator


    echo "-------------------------------------------------------------------------------"
    echo " Install mini lab setup WF from quickstart github repository"
    echo "-------------------------------------------------------------------------------"
    echo "  >> SelfDemoSetup"
    ln -fsn ../workflow_quickstart_minilab/SelfDemoSetup SelfDemoSetup;
    ln -fsn ../workflow_quickstart_minilab/.meta_SelfDemoSetup .meta_SelfDemoSetup;

    echo "DONE"

}

install_mano_workflows() {

    echo "-------------------------------------------------------------------------------"
    echo " Install MANO Workflows from OpenMSA github repository"
    echo "-------------------------------------------------------------------------------"
    cd /opt/fmc_repository/Process;
    echo "  >> WF references and libs"
    ln -fsn ../php_sdk/Reference Reference;
    ln -fsn ../php_sdk/.meta_Reference .meta_Reference;
    echo "  >> ETSI-MANO $TAG_WF_ETSI_MANO"
    ln -fsn ../etsi-mano-workflows etsi-mano-workflows
 
    echo "DONE"

}

install_ccla_lib() {

    echo "-------------------------------------------------------------------------------"
    echo " Install Cloudclapp library from OpenMSA github repository"
    echo "-------------------------------------------------------------------------------"
    
    cd /opt/fmc_repository/Blueprints;
    echo "  >> CCLA references and libs"
    ln -fsn ../OpenMSA_Blueprints/Catalog Catalog;
    echo "DONE"
}

finalize_install() {
    echo "-------------------------------------------------------------------------------"
    echo " update file owner to ncuser.ncuser"
    echo "-------------------------------------------------------------------------------"
    chown -R ncuser:ncuser /opt/fmc_repository/*;
    if [[ "$install_type" = "all" || "$install_type" = "da" ]]; then
        chown -R ncuser.ncuser /opt/devops/OpenMSA_Adapters
        chown -R ncuser.ncuser /opt/devops/OpenMSA_Adapters/adapters/*
        chown -R ncuser.ncuser /opt/devops/OpenMSA_Adapters/vendor/*
    fi

    echo "DONE"
    if [[ "$install_type" = "all" || "$install_type" = "da" ]]; then
        echo "-------------------------------------------------------------------------------"
        echo " service restart"
        echo "-------------------------------------------------------------------------------"
        echo "  >> execute [sudo docker compose restart msa_dev] to update the Repository"
        echo "  >> execute [sudo docker compose restart msa_sms] to restart the CoreEngine service"
        echo "  >> execute [sudo docker compose restart msa_api] to restart the API service"
        echo "DONE"
    fi
}

usage() {
    echo "usage: $PROG all|ms|wf|da|py|mano|quickstart [--lic] [-y]"
    echo
    echo "this script installs some librairies available @github.com/openmsa"
    echo
    echo "Commands:"
    echo "all:          install/update everything: workflows, microservices and adapters"
    echo "ms:           install/update the microservices from https://github.com/openmsa/Microservices"
    echo "wf:           install/update the worfklows from https://github.com/openmsa/Workflows"
    echo "da:           install/update the adapters from https://github.com/openmsa/Adapters"
    echo "mano:         install/update the mano from https://github.com/openmsa/etsi-mano"
    echo "py:           install/update the python-sdk from https://github.com/openmsa/python-sdk"
    echo "ccla:         install/update the cloudclapp libraries, like blueprints from https://github.com/openmsa/Blueprints"
    echo
    echo "Options:"
    echo "--lic:          force license installation"
    echo "-y:             answer yes for all questions"
    exit 0
}

main() {

    cmd=$1

    if [[ -z "$cmd" || "$cmd" == --help ]];
    then
        usage
    fi

    shift

    while [ ! -z $1 ]
    do
        echo $1
        option=$1
        case $option in
            --lic)
                INSTALL_LICENSE=true
                ;;
            -y)
                ASSUME_YES=true
                ;;
            *)
            echo "Error: unknown option: $option"
            usage
            ;;
        esac
        shift
    done

    case $cmd in

        kibana_dashboard)
            install_license $option
            init_intall
            update_all_github_repo $cmd
            install_workflows
            ;;
        all)
            install_license $option
            init_intall
            update_all_github_repo $cmd
            install_microservices
            install_workflows
            install_python_sdk
            ;;
        ms)
            install_license  $option
            init_intall
            update_all_github_repo  $cmd
            install_microservices
            ;;
        wf)
            install_license  $option
            init_intall
            update_all_github_repo  $cmd
            install_workflows
            ;;
        da)
            install_license  $option
            init_intall
            update_all_github_repo  $cmd
            ;;
        py)
            init_intall
            update_all_github_repo  $cmd
            install_python_sdk
            ;;
        mano)
            init_intall
            update_all_github_repo  $cmd
            install_mano_workflows
            ;;
        ccla)
            init_intall
            update_all_github_repo  $cmd
            install_ccla_lib
            ;;
        *)
            echo "Error: unknown command: $1"
            usage
            ;;
    esac
    finalize_install
}


main "$@"
