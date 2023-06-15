import click
import gitlab
import paramiko
import os
import requests
import yaml
from io import StringIO

requests.packages.urllib3.disable_warnings()

def generate():
    key = paramiko.RSAKey.generate(2048)
    out = StringIO()
    key.write_private_key(out)
    private_key = out.getvalue()
    public_key = f"{key.get_name()} {key.get_base64()}"

    return private_key, public_key

@click.command()
@click.option('--gitlab_url', prompt='Please input gitlab url')
@click.option('--token', prompt='Please input gitlab root token')
@click.option('--group_name', prompt='Please input group name')
@click.option('--project_name', prompt='Please input project name')
@click.option('--app_call_back_url', prompt='Please input call back url for app')
@click.option('--output_base', default="/opt/out/git", help='The base folder to write init info')
def main(gitlab_url, token, group_name, project_name, app_call_back_url, output_base):
    gl = gitlab.Gitlab(gitlab_url, private_token=token, ssl_verify=False)

    app_name = "nautes"
    def create_gitlab_application():
        apps = gl.applications.list()
        for app in apps:
            if app.application_name == app_name:
                app.delete()
        app = gl.applications.create({'name': app_name, 'redirect_uri': app_call_back_url, 'scopes': 'api read_api read_user read_repository openid profile email'})
        return app.application_id, app.secret

    access_token_name = "base-operator"
    def create_access_token():
        # 1 is root ID
        user = gl.users.get(1)
        tokens = gl.personal_access_tokens.list(user_id=1)
        for token in tokens:
            if token.name == access_token_name:
                token.delete()
        return user.personal_access_tokens.create({"name": access_token_name, 'scopes': 'read_api'})

    def create_group():
        try :
            group = gl.groups.get(group_name)
        except gitlab.exceptions.GitlabGetError as e:
            if e.response_code == 404:
                group = gl.groups.create({'name': group_name, 'path': group_name})
            else:
                raise e

        return group.id


    def create_project(group_id):
        try: 
            project = gl.projects.get(f'{group_name}/{project_name}')
        except gitlab.exceptions.GitlabGetError as e:
            if e.response_code == 404:
                project = gl.projects.create({'name': project_name, 'namespace_id': group_id, 'initialize_with_readme': True})
            else:
                raise e

        return project.id, project.ssh_url_to_repo

    deploy_key_name = 'tenant-repo'
    def create_deploykey(project_id):
        project = gl.projects.get(project_id)
        for deploy_key in project.keys.list():
            if deploy_key.title == deploy_key_name:
                return None, 0
        keypair = generate()
        deploykey = project.keys.create({'title': deploy_key_name, 'key': keypair[1], 'can_push': True})
        return keypair[0], deploykey.id

    with gl:
        client_id, client_secret = create_gitlab_application()
        access_token = create_access_token()
        group_id = create_group()
        project_id, ssh_addr = create_project(group_id)
        private_key, deploykey_id = create_deploykey(project_id)

        outputs = {
            "client_id" : client_id,
            "client_sercret": client_secret,
            "access_token": access_token.token,
            "tenant_repo_id": str(project_id),
            "tenant_repo_ssh_addr": ssh_addr
        }

        filePath = os.path.join(output_base, "infos.yaml")
        with open(filePath, 'w') as f:
            yaml.dump(outputs, f)

        sshKeyPath = os.path.join(output_base, "tenant_repo_private.key")
        with open(sshKeyPath, "w") as f:
            f.write(private_key)


if __name__ == '__main__':
    main()

