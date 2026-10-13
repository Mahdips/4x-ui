import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Button,
  Card,
  Form,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Switch,
  Table,
  Typography,
  message,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { HttpUtil } from '@/utils';
import { keys } from '@/api/queryKeys';

const { Title, Paragraph, Text } = Typography;

interface AdminRow {
  id: number;
  username: string;
  role: string;
  enabled: boolean;
  isOwner: boolean;
}

type Role = 'admin' | 'limited';

function apiPath(suffix: string): string {
  return `/panel/api/setting/admins${suffix}`;
}

export default function AdminsTab() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [createForm] = Form.useForm();
  const [createOpen, setCreateOpen] = useState(false);

  const { data: rows = [], isPending } = useQuery<AdminRow[]>({
    queryKey: keys.admins(),
    queryFn: async () => {
      const res = await HttpUtil.get<AdminRow[]>(apiPath(''), undefined, { silent: true });
      if (!res.success) throw new Error(res.msg);
      return res.obj ?? [];
    },
  });

  function invalidate() {
    return queryClient.invalidateQueries({ queryKey: keys.admins() });
  }

  const createMutation = useMutation({
    mutationFn: async (values: { username: string; password: string; role: Role }) => {
      const res = await HttpUtil.post(apiPath('/create'), values, { silent: true });
      if (!res.success) throw new Error(res.msg);
    },
    onSuccess: async () => {
      message.success(t('pages.settings.adminCreateSuccess'));
      createForm.resetFields();
      setCreateOpen(false);
      await invalidate();
    },
    onError: (err: Error) => message.error(err.message),
  });

  const enabledMutation = useMutation({
    mutationFn: async ({ id, enabled }: { id: number; enabled: boolean }) => {
      const res = await HttpUtil.post(apiPath(`/setEnabled/${id}`), { enabled }, { silent: true });
      if (!res.success) throw new Error(res.msg);
    },
    onSuccess: () => invalidate(),
    onError: (err: Error) => message.error(err.message),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: number) => {
      const res = await HttpUtil.post(apiPath(`/delete/${id}`), undefined, { silent: true });
      if (!res.success) throw new Error(res.msg);
    },
    onSuccess: async () => {
      message.success(t('pages.settings.adminDeleteSuccess'));
      await invalidate();
    },
    onError: (err: Error) => message.error(err.message),
  });

  async function submitCreate() {
    let values: { username: string; password: string; role: Role };
    try {
      values = await createForm.validateFields();
    } catch {
      return;
    }
    createMutation.mutate(values);
  }

  function toggleEnabled(row: AdminRow, enabled: boolean) {
    if (row.isOwner) {
      message.warning(t('pages.settings.adminDisabledOwner'));
      return;
    }
    enabledMutation.mutate({ id: row.id, enabled });
  }

  function removeAdmin(row: AdminRow) {
    if (row.isOwner) return;
    deleteMutation.mutate(row.id);
  }

  const columns: ColumnsType<AdminRow> = [
    {
      title: t('pages.settings.adminUsername'),
      dataIndex: 'username',
      key: 'username',
      render: (username: string, row) => (
        <Space>
          <Text strong>{username}</Text>
          {row.isOwner && <Text type="secondary">({t('pages.settings.adminOwner')})</Text>}
        </Space>
      ),
    },
    {
      title: t('pages.settings.adminRole'),
      dataIndex: 'role',
      key: 'role',
      render: (role: string) =>
        role === 'admin'
          ? t('pages.settings.adminRoleAdmin')
          : t('pages.settings.adminRoleLimited'),
    },
    {
      title: t('pages.settings.adminEnabled'),
      dataIndex: 'enabled',
      key: 'enabled',
      render: (enabled: boolean, row) => (
        <Switch
          checked={enabled}
          disabled={row.isOwner}
          loading={enabledMutation.isPending}
          onChange={(checked) => toggleEnabled(row, checked)}
        />
      ),
    },
    {
      title: t('actions'),
      key: 'actions',
      width: 90,
      render: (_value, row) =>
        row.isOwner ? null : (
          <Popconfirm
            title={t('pages.settings.adminDeleteConfirm')}
            okText={t('delete')}
            cancelText={t('cancel')}
            onConfirm={() => removeAdmin(row)}
          >
            <Button type="primary" danger size="small" loading={deleteMutation.isPending}>
              {t('delete')}
            </Button>
          </Popconfirm>
        ),
    },
  ];

  return (
    <div>
      <Card hoverable>
        <Title level={5}>{t('pages.settings.admins')}</Title>
        <Paragraph type="secondary">{t('pages.settings.adminsDesc')}</Paragraph>
        <Paragraph type="secondary" style={{ marginBottom: 16 }}>
          <ul style={{ margin: 0, paddingLeft: 18 }}>
            <li>{t('pages.settings.adminRoleAdminDesc')}</li>
            <li>{t('pages.settings.adminRoleLimitedDesc')}</li>
          </ul>
        </Paragraph>
        <Space style={{ marginBottom: 12 }}>
          <Button type="primary" onClick={() => setCreateOpen(true)}>
            {t('pages.settings.addAdmin')}
          </Button>
        </Space>
        <Table<AdminRow>
          rowKey="id"
          loading={isPending}
          columns={columns}
          dataSource={rows}
          pagination={false}
        />
      </Card>

      <Modal
        open={createOpen}
        title={t('pages.settings.addAdmin')}
        okText={t('pages.settings.addAdmin')}
        cancelText={t('cancel')}
        confirmLoading={createMutation.isPending}
        onCancel={() => setCreateOpen(false)}
        onOk={() => void submitCreate()}
      >
        <Form form={createForm} layout="vertical" initialValues={{ role: 'limited' }}>
          <Form.Item
            name="username"
            label={t('pages.settings.adminUsername')}
            rules={[{ required: true }]}
          >
            <Input autoComplete="off" />
          </Form.Item>
          <Form.Item
            name="password"
            label={t('pages.settings.adminPassword')}
            rules={[{ required: true }]}
          >
            <Input.Password autoComplete="new-password" />
          </Form.Item>
          <Form.Item name="role" label={t('pages.settings.adminRole')}>
            <Select
              options={[
                { value: 'limited', label: t('pages.settings.adminRoleLimited') },
                { value: 'admin', label: t('pages.settings.adminRoleAdmin') },
              ]}
            />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
